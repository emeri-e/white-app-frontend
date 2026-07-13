package com.example.whiteapp

import android.util.Log
import io.netty.bootstrap.Bootstrap
import io.netty.bootstrap.ServerBootstrap
import io.netty.buffer.Unpooled
import io.netty.channel.*
import io.netty.channel.nio.NioEventLoopGroup
import io.netty.channel.socket.SocketChannel
import io.netty.channel.socket.nio.NioServerSocketChannel
import io.netty.channel.socket.nio.NioSocketChannel
import io.netty.handler.codec.http.*
import io.netty.util.ReferenceCountUtil

class ConnectProxyServer(private val listenPort: Int, private val mitmPort: Int) {
    private var bossGroup: EventLoopGroup? = null
    private var workerGroup: EventLoopGroup? = null
    private var serverChannel: Channel? = null

    fun start() {
        bossGroup = NioEventLoopGroup(1)
        workerGroup = NioEventLoopGroup(4)

        val b = ServerBootstrap()
        b.group(bossGroup, workerGroup)
            .channel(NioServerSocketChannel::class.java)
            .childHandler(object : ChannelInitializer<SocketChannel>() {
                override fun initChannel(ch: SocketChannel) {
                    ch.pipeline().addLast(HttpServerCodec())
                    ch.pipeline().addLast(HttpObjectAggregator(1024 * 64))
                    ch.pipeline().addLast(ConnectProxyHandler(mitmPort))
                }
            })

        serverChannel = b.bind("127.0.0.1", listenPort).sync().channel()
        Log.i("ConnectProxyServer", "ConnectProxyServer started on 127.0.0.1:$listenPort, forwarding to MITM at $mitmPort")
    }

    fun stop() {
        try {
            serverChannel?.close()?.sync()
        } catch (e: Exception) {
            Log.e("ConnectProxyServer", "Error closing server channel: ${e.message}")
        } finally {
            serverChannel = null
        }
        
        try {
            bossGroup?.shutdownGracefully()
            workerGroup?.shutdownGracefully()
        } catch (e: Exception) {
            Log.e("ConnectProxyServer", "Error shutting down event loops: ${e.message}")
        } finally {
            bossGroup = null
            workerGroup = null
        }
    }
}

class ConnectProxyHandler(private val mitmPort: Int) : SimpleChannelInboundHandler<FullHttpRequest>() {
    private var outboundChannel: Channel? = null

    override fun channelRead0(ctx: ChannelHandlerContext, msg: FullHttpRequest) {
        val clientChannel = ctx.channel()
        
        if (msg.method() == HttpMethod.CONNECT) {
            val uri = msg.uri()
            val hostAndPort = parseHostAndPort(uri)
            val host = hostAndPort.first
            val port = hostAndPort.second

            val shouldBypass = SelectiveMitmManager.shouldBypass(host, ctx)

            if (shouldBypass) {
                Log.i("ConnectProxyHandler", "Passthrough (raw TCP tunnel) enabled for: $host:$port")
                connectDirect(ctx, host, port, msg)
            } else {
                Log.d("ConnectProxyHandler", "MITM proxy routing enabled for: $host:$port")
                msg.retain() // Retain msg for async use in connectMitm
                connectMitm(ctx, host, port, msg)
            }
        } else {
            // Non-CONNECT requests: Extract host and port and forward to MITM proxy
            val hostHeader = msg.headers().get(HttpHeaderNames.HOST)
            val host = hostHeader?.split(":")?.firstOrNull() ?: "127.0.0.1"
            val port = if (hostHeader?.contains(":") == true) hostHeader.split(":")[1].toInt() else 80
            Log.d("ConnectProxyHandler", "Forwarding non-CONNECT HTTP request to MITM for: $host:$port")
            msg.retain() // Retain msg for async use in connectMitm
            connectMitm(ctx, host, port, msg)
        }
    }

    private fun connectDirect(ctx: ChannelHandlerContext, host: String, port: Int, msg: FullHttpRequest) {
        val clientChannel = ctx.channel()
        val b = Bootstrap()
        b.group(clientChannel.eventLoop())
            .channel(NioSocketChannel::class.java)
            .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000)
            .option(ChannelOption.SO_KEEPALIVE, true)
            .handler(object : ChannelInitializer<SocketChannel>() {
                override fun initChannel(ch: SocketChannel) {
                    ch.pipeline().addLast(RelayHandler(clientChannel))
                }
            })

        b.connect(host, port).addListener(object : ChannelFutureListener {
            override fun operationComplete(future: ChannelFuture) {
                if (future.isSuccess) {
                    val serverChannel = future.channel()
                    outboundChannel = serverChannel

                    // Respond 200 Connection Established to client
                    val response = DefaultFullHttpResponse(
                        HttpVersion.HTTP_1_1,
                        HttpResponseStatus(200, "Connection Established")
                    )
                    clientChannel.writeAndFlush(response).addListener(ChannelFutureListener { f ->
                        if (f.isSuccess) {
                            // Remove HTTP parser and handler from client pipeline
                            clientChannel.pipeline().remove(HttpServerCodec::class.java)
                            clientChannel.pipeline().remove(HttpObjectAggregator::class.java)
                            clientChannel.pipeline().remove(this@ConnectProxyHandler)

                            // Add relay handler to client pipeline
                            clientChannel.pipeline().addLast(RelayHandler(serverChannel))
                        } else {
                            serverChannel.close()
                            clientChannel.close()
                        }
                    })
                } else {
                    val response = DefaultFullHttpResponse(
                        HttpVersion.HTTP_1_1,
                        HttpResponseStatus.BAD_GATEWAY
                    )
                    clientChannel.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE)
                }
            }
        })
    }

    private fun connectMitm(ctx: ChannelHandlerContext, host: String, port: Int, msg: FullHttpRequest) {
        val clientChannel = ctx.channel()
        
        // Share a TLS record parser between both directions (upload and download)
        val parser = TlsRecordParser()

        val b = Bootstrap()
        b.group(clientChannel.eventLoop())
            .channel(NioSocketChannel::class.java)
            .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 5000)
            .option(ChannelOption.SO_KEEPALIVE, true)
            .handler(object : ChannelInitializer<SocketChannel>() {
                override fun initChannel(ch: SocketChannel) {
                    ch.pipeline().addLast(HttpClientCodec())
                    ch.pipeline().addLast(RelayHandler(clientChannel, host, port, parser, isMitmSide = true))
                }
            })

        b.connect("127.0.0.1", mitmPort).addListener(object : ChannelFutureListener {
            override fun operationComplete(future: ChannelFuture) {
                if (future.isSuccess) {
                    val mitmChannel = future.channel()
                    outboundChannel = mitmChannel

                    // Forward the original request
                    mitmChannel.writeAndFlush(msg).addListener(ChannelFutureListener { f ->
                        try {
                            if (mitmChannel.pipeline().get(HttpClientCodec::class.java) != null) {
                                mitmChannel.pipeline().remove(HttpClientCodec::class.java)
                            }
                        } catch (e: Exception) {
                            Log.e("ConnectProxyHandler", "Failed to remove HttpClientCodec: ${e.message}")
                        }

                        if (f.isSuccess) {
                            clientChannel.pipeline().remove(HttpServerCodec::class.java)
                            clientChannel.pipeline().remove(HttpObjectAggregator::class.java)
                            clientChannel.pipeline().remove(this@ConnectProxyHandler)

                            clientChannel.pipeline().addLast(RelayHandler(mitmChannel, host, port, parser, isMitmSide = false))
                        } else {
                            Log.e("ConnectProxyHandler", "Failed to forward CONNECT request for $host: ${f.cause()?.message}")
                            mitmChannel.close()
                            clientChannel.close()
                        }
                    })
                } else {
                    ReferenceCountUtil.release(msg) // Release retained msg if connection to LittleProxy fails
                    val response = DefaultFullHttpResponse(
                        HttpVersion.HTTP_1_1,
                        HttpResponseStatus.BAD_GATEWAY
                    )
                    clientChannel.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE)
                }
            }
        })
    }

    override fun exceptionCaught(ctx: ChannelHandlerContext, cause: Throwable) {
        Log.e("ConnectProxyHandler", "Exception in proxy handler: ${cause.message}")
        outboundChannel?.let { closeOnFlush(it) }
        ctx.close()
    }

    override fun channelInactive(ctx: ChannelHandlerContext) {
        outboundChannel?.let { closeOnFlush(it) }
        super.channelInactive(ctx)
    }

    private fun parseHostAndPort(uri: String): Pair<String, Int> {
        val parts = uri.split(":")
        val host = parts[0]
        val port = if (parts.size > 1) parts[1].toInt() else 443
        return Pair(host, port)
    }

    private fun closeOnFlush(ch: Channel) {
        if (ch.isActive) {
            ch.writeAndFlush(Unpooled.EMPTY_BUFFER).addListener(ChannelFutureListener.CLOSE)
        }
    }
}

class RelayHandler(
    private val relayChannel: Channel,
    private val host: String? = null,
    private val port: Int = 443,
    private val parser: TlsRecordParser? = null,
    private val isMitmSide: Boolean = false
) : ChannelInboundHandlerAdapter() {

    override fun handlerAdded(ctx: ChannelHandlerContext) {
        Log.d("RelayHandler", "handlerAdded for host=$host (isMitmSide=$isMitmSide)")
        super.handlerAdded(ctx)
    }

    override fun channelActive(ctx: ChannelHandlerContext) {
        Log.d("RelayHandler", "channelActive for host=$host (isMitmSide=$isMitmSide)")
        super.channelActive(ctx)
    }

    override fun channelRead(ctx: ChannelHandlerContext, msg: Any) {
        Log.d("RelayHandler", "channelRead for host=$host (isMitmSide=$isMitmSide): msgType=${msg::class.java.name}")
        if (msg is io.netty.buffer.ByteBuf && parser != null && !isMitmSide) {
            parser.processBytes(msg)
        }

        if (relayChannel.isActive) {
            relayChannel.writeAndFlush(msg).addListener(ChannelFutureListener { future ->
                if (!future.isSuccess) {
                    Log.w("RelayHandler", "writeAndFlush failed for host=$host (isMitmSide=$isMitmSide): ${future.cause()?.message}")
                    future.channel().close()
                    ctx.channel().close()
                }
            })
        } else {
            Log.w("RelayHandler", "relayChannel inactive, discarding msg for host=$host (isMitmSide=$isMitmSide)")
            ReferenceCountUtil.release(msg)
            ctx.channel().close()
        }
    }

    override fun channelInactive(ctx: ChannelHandlerContext) {
        Log.d("RelayHandler", "channelInactive for host=$host (isMitmSide=$isMitmSide)")
        if (relayChannel.isActive) {
            relayChannel.writeAndFlush(Unpooled.EMPTY_BUFFER).addListener(ChannelFutureListener.CLOSE)
        }

        if (host != null && parser != null && !isMitmSide && port == 443) {
            Log.d("RelayHandler", "Checking TLS handshake result for $host. sawHandshakeStart=${parser.sawHandshakeStart} sawHandshakeSuccess=${parser.sawHandshakeSuccess} sawApplicationData=${parser.sawApplicationData}")
            if (parser.sawHandshakeStart && !parser.sawHandshakeSuccess && !parser.sawApplicationData) {
                Log.w("ConnectProxyHandler", "🔓 HTTPS connection to $host:$port failed handshake (ClientHello sent but no success or app data). Learning bypass.")
                SelectiveMitmManager.recordFailure(host, ctx)
            }
        }
        super.channelInactive(ctx)
    }

    override fun exceptionCaught(ctx: ChannelHandlerContext, cause: Throwable) {
        Log.e("RelayHandler", "exceptionCaught for host=$host (isMitmSide=$isMitmSide): ${cause.message}")
        ctx.channel().close()
    }
}

class TlsRecordParser {
    private var state = 0 // 0: type, 1: v1, 2: v2, 3: len, 4: payload
    private var recordType = 0
    private var payloadBytesRemaining = 0
    private var lengthBytesRead = 0
    private var lengthValue = 0
    
    @Volatile var sawHandshakeStart = false
        private set
    @Volatile var sawApplicationData = false
        private set
    @Volatile var sawHandshakeSuccess = false
        private set

    fun processBytes(buf: io.netty.buffer.ByteBuf) {
        val readerIndex = buf.readerIndex()
        val writerIndex = buf.writerIndex()
        var i = readerIndex
        while (i < writerIndex) {
            val b = buf.getByte(i)
            when (state) {
                0 -> { // Read Type
                    recordType = b.toInt() and 0xFF
                    state = 1
                }
                1 -> { // Read Version Byte 1
                    state = 2
                }
                2 -> { // Read Version Byte 2
                    state = 3
                    lengthBytesRead = 0
                    lengthValue = 0
                }
                3 -> { // Read Length Byte 1 & 2
                    lengthValue = (lengthValue shl 8) or (b.toInt() and 0xFF)
                    lengthBytesRead++
                    if (lengthBytesRead == 2) {
                        payloadBytesRemaining = lengthValue
                        if (payloadBytesRemaining > 20480 || payloadBytesRemaining < 0) {
                            state = 0 // Malformed/non-TLS, reset
                        } else {
                            Log.d("TlsRecordParser", "Parsed TLS Record: Type=$recordType, Length=$payloadBytesRemaining")
                            if (recordType == 0x16) { // Handshake (ClientHello is 0x16)
                                sawHandshakeStart = true
                            }
                            if (recordType == 0x17) {
                                sawApplicationData = true
                            }
                            if (recordType == 0x14) { // ChangeCipherSpec
                                sawHandshakeSuccess = true
                            }
                            if (payloadBytesRemaining > 0) {
                                state = 4
                            } else {
                                state = 0
                            }
                        }
                    }
                }
                4 -> { // Skip Payload
                    val chunk = minOf(payloadBytesRemaining, writerIndex - i)
                    payloadBytesRemaining -= chunk
                    i += chunk - 1
                    if (payloadBytesRemaining == 0) {
                        state = 0
                    }
                }
            }
            i++
        }
    }
}
