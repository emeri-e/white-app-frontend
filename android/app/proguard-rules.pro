# TensorFlow Lite ProGuard/R8 Rules
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# Suppress warnings for missing optional dependencies (like the GPU delegate options class)
-dontwarn org.tensorflow.**
-dontwarn org.tensorflow.lite.**

# Netty R8 / ProGuard rules
-dontwarn io.netty.**
-keep class io.netty.** { *; }

# LittleProxy / MITM rules
-dontwarn org.littleshoot.**
-keep class org.littleshoot.** { *; }

-dontwarn com.github.ganskef.**
-keep class com.github.ganskef.** { *; }

# Suppress warnings for missing optional Netty dependencies
-dontwarn com.aayushatharva.brotli4j.**
-dontwarn com.jcraft.jzlib.**
-dontwarn reactor.blockhound.**

# BouncyCastle Rules (critical for CA generation in release builds)
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn javax.naming.**
