import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/core/services/media_cache_service.dart';
import 'dart:io';
import 'dart:async';
import 'package:whiteapp/core/services/offline_manager.dart';
import 'package:whiteapp/core/parsers/srt_parser.dart';
import 'package:http/http.dart' as http;
import 'package:whiteapp/core/services/tts_service.dart';
import 'package:whiteapp/core/constants/env.dart';

class MediaDisplayWidget extends StatefulWidget {
  final Map<String, dynamic> media;
  final Function(int) onMediaCompleted;

  const MediaDisplayWidget({
    super.key,
    required this.media,
    required this.onMediaCompleted,
  });

  @override
  State<MediaDisplayWidget> createState() => _MediaDisplayWidgetState();
}

class _MediaDisplayWidgetState extends State<MediaDisplayWidget> {
  VideoPlayerController? _videoController;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  bool _showCommentsSection = false;
  bool _isCached = false;
  
  // Subtitles
  List<SubtitleLine> _currentSubtitles = [];
  String? _activeSubtitleText;
  String? _selectedSubLang;
  bool _showSubtitles = true;

  // TTS
  final TtsService _ttsService = TtsService();
  bool _isSpeaking = false;
  bool _isTtsPaused = false;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
    _likesCount = widget.media['likes_count'] ?? 0;
    _isLiked = widget.media['is_liked'] ?? false;
    
    _ttsService.init();
    _ttsService.tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _ttsService.tts.setCompletionHandler(() => setState(() { _isSpeaking = false; _isTtsPaused = false; }));
    _ttsService.tts.setErrorHandler((_) => setState(() { _isSpeaking = false; _isTtsPaused = false; }));

    if (widget.media['media_type'] == 'video' || widget.media['media_type'] == 'audio') {
      _initializeVideo();
      _startProgressTimer();
    } else {
      // Auto-complete non-video media after 3 seconds, or completed immediately
      Timer(const Duration(seconds: 2), () {
        if (mounted) widget.onMediaCompleted(widget.media['id']);
      });
    }
  }

  Future<void> _checkCacheStatus() async {
    final mediaId = widget.media['id'].toString();
    final isTracked = await OfflineManager.isTrackedForOffline(mediaId);
    if (mounted) {
      setState(() {
        _isCached = isTracked;
      });
    }
  }

  Future<void> _toggleCache() async {
    if (_isCached) {
      await OfflineManager.removeFromOffline(widget.media);
      setState(() {
        _isCached = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from offline cache')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading for offline viewing...')));
      try {
        await OfflineManager.saveForOffline(widget.media);
        setState(() {
          _isCached = true;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved for offline viewing!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String? _errorMessage;

  Future<void> _initializeVideo() async {
    try {
      final urlValue = widget.media['url'] ?? widget.media['file'];
      if (urlValue == null || urlValue.toString().isEmpty) {
        setState(() {
          _errorMessage = "Media source not found.";
        });
        return;
      }
      String url = urlValue.toString();

      // Ensure absolute URL for Web or whenever host is missing
      if (!url.startsWith('http')) {
        final apiBase = Env.apiBase; // e.g. "http://localhost:8000/api"
        final host = apiBase.split('/api').first; // e.g. "http://localhost:8000"
        url = "$host$url";
      }

      if (kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        final cachedPath = await MediaCacheService.getCachedFilePath(url);
        if (cachedPath != null) {
          _videoController = VideoPlayerController.file(File(cachedPath));
        } else {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
        }
      }
      
      await _videoController!.initialize();
      
      final lastPosition = widget.media['last_position_seconds'] as int?;
      final isCompleted = widget.media['is_completed'] as bool? ?? false;
      
      // Seek to last known position if not completed
      if (lastPosition != null && lastPosition > 0 && !isCompleted && 
          lastPosition < _videoController!.value.duration.inSeconds) {
        await _videoController!.seekTo(Duration(seconds: lastPosition));
      }
      
      _videoController!.addListener(_checkVideoCompletion);
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load media: $e";
        });
      }
    }
  }

  void _checkVideoCompletion() {
    if (_videoController != null && 
        _videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration > Duration.zero) {
      widget.onMediaCompleted(widget.media['id']);
    }
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_videoController != null && _videoController!.value.isPlaying) {
        _saveCurrentPosition();
        // Log 10 seconds of actual watch time to the backend
        RecoveryService.logMediaTime(widget.media['id'], 10).catchError((e) {
            // fail silently on background ping
        });
      }
    });
  }

  Future<void> _saveCurrentPosition() async {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final position = _videoController!.value.position.inSeconds;
    try {
      if (position > 0) {
        await RecoveryService.saveMediaProgress(widget.media['id'], position);
      }
    } catch (e) {
      // Background save, fail silently
    }
  }

  @override
  void dispose() {
    _saveCurrentPosition();
    _ttsService.stop();
    _videoController?.removeListener(_checkVideoCompletion);
    _videoController?.dispose();
    _controlsTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _videoController != null && _videoController!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final newPos = _videoController!.value.position + Duration(seconds: seconds);
    _videoController!.seekTo(newPos);
    _startControlsTimer(); // Keep controls visible after seeking
    setState(() {
      _showControls = true;
    });
  }

  Future<void> _loadSubtitles(String url, String lang) async {
    try {
      final content = await RecoveryService.fetchSubtitles(url);
      final lines = SrtParser.parse(content);
      setState(() {
        _currentSubtitles = lines;
        _selectedSubLang = lang;
        _showSubtitles = true;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load $lang subtitles: $e')));
    }
  }

  void _updateActiveSubtitle(Duration position) {
    if (!_showSubtitles || _currentSubtitles.isEmpty) {
      if (_activeSubtitleText != null) setState(() => _activeSubtitleText = null);
      return;
    }

    // Binary search would be better if list is huge, but for subtitles linear is usually fine
    final activeLine = _currentSubtitles.where((line) => position >= line.start && position <= line.end).firstOrNull;

    if (activeLine?.text != _activeSubtitleText) {
      setState(() {
        _activeSubtitleText = activeLine?.text;
      });
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    
    setState(() {
      if (_videoController!.value.isPlaying) {
        _saveCurrentPosition(); // Save immediately on pause
        _videoController!.pause();
        _showControls = true;
        _controlsTimer?.cancel();
      } else {
        _videoController!.play();
        _startControlsTimer();
      }
    });
  }

  Future<void> _toggleLike() async {
    try {
      if (_isLiked) {
        setState(() {
          _isLiked = false;
          _likesCount--;
        });
        await RecoveryService.unlikeMedia(widget.media['id']);
      } else {
        setState(() {
          _isLiked = true;
          _likesCount++;
        });
        await RecoveryService.likeMedia(widget.media['id']);
      }
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }


  void _toggleTts() {
    final text = widget.media['content'] ?? '';
    if (text.isEmpty) return;

    if (_isSpeaking && !_isTtsPaused) {
      _ttsService.pause();
      setState(() => _isTtsPaused = true);
    } else if (_isSpeaking && _isTtsPaused) {
      _ttsService.speak(text);
      setState(() => _isTtsPaused = false);
    } else {
      _ttsService.speak(text);
    }
  }

  void _stopTts() {
    _ttsService.stop();
    setState(() {
      _isSpeaking = false;
      _isTtsPaused = false;
    });
  }

  void _toggleComments() {
    setState(() {
      _showCommentsSection = !_showCommentsSection;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final mediaType = widget.media['media_type'];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Content
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _buildMediaContent(mediaType),
          ),
          
          // Interaction Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                   widget.media['title'] ?? 'Untitled',
                   style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                 ),
                 const SizedBox(height: 12),
                 Row(
                   children: [
                     _InteractionButton(
                       icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                       color: _isLiked ? Colors.redAccent : Colors.white70,
                       label: '$_likesCount',
                       onTap: _toggleLike,
                     ),
                     const SizedBox(width: 16),
                     _InteractionButton(
                       icon: Icons.comment,
                       color: _showCommentsSection ? Colors.blueAccent : Colors.white70,
                       label: 'Comments',
                       onTap: _toggleComments,
                     ),
                     const SizedBox(width: 16),
                      _InteractionButton(
                        icon: _isCached ? Icons.offline_pin : Icons.download_rounded,
                        color: _isCached ? Colors.greenAccent : Colors.white70,
                        label: _isCached ? 'Saved' : 'Save',
                        onTap: _toggleCache,
                      ),
                      const Spacer(),
                      if (mediaType == 'text')
                        IconButton(
                          icon: Icon(_isSpeaking && !_isTtsPaused ? Icons.pause_circle : Icons.play_circle, color: Colors.blueAccent),
                          onPressed: _toggleTts,
                        ),
                      if (mediaType == 'text' && _isSpeaking)
                         IconButton(
                          icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                          onPressed: _stopTts,
                        ),
                      if (mediaType == 'video' && widget.media['subtitles'] != null && (widget.media['subtitles'] as List).isNotEmpty)
                        PopupMenuButton<Map<String, dynamic>>(
                          icon: Icon(Icons.subtitles, color: _selectedSubLang != null ? Colors.blueAccent : Colors.white70),
                          onSelected: (sub) {
                             if (sub['lang'] == 'none') {
                               setState(() {
                                 _selectedSubLang = null;
                                 _currentSubtitles = [];
                                 _activeSubtitleText = null;
                               });
                             } else {
                               _loadSubtitles(sub['url'], sub['label'] ?? sub['lang']);
                             }
                          },
                          itemBuilder: (context) {
                            final List<dynamic> subs = widget.media['subtitles'];
                            return [
                              const PopupMenuItem(value: {'lang': 'none'}, child: Text('Off')),
                              ...subs.map((s) => PopupMenuItem(value: s as Map<String, dynamic>, child: Text(s['label'] ?? s['lang']))).toList(),
                            ];
                          },
                        ),
                   ],
                 ),
              ],
            ),
          ),
          
          // Inline Comments
          if (_showCommentsSection)
            _InlineCommentsSection(
              mediaId: widget.media['id'], 
              initialComments: widget.media['comments'] ?? [],
            ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(String? mediaType) {
    if (mediaType == 'video') {
      if (_errorMessage != null) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }
      if (_videoController == null || !_videoController!.value.isInitialized) {
        return const AspectRatio(aspectRatio: 16/9, child: Center(child: CircularProgressIndicator()));
      }
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            // Subtitle Overlay
            if (_showSubtitles && _activeSubtitleText != null)
              Positioned(
                bottom: 60,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _activeSubtitleText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ValueListenableBuilder(
              valueListenable: _videoController!,
              builder: (context, VideoPlayerValue value, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateActiveSubtitle(value.position);
                });
                return const SizedBox.shrink();
              },
            ),
            if (_showControls)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls, // Allow tapping overlay to hide
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black45,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.fullscreen, color: Colors.white),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fullscreen not implemented yet')));
                            },
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10, color: Colors.white, size: 40),
                                onPressed: () => _seekRelative(-10),
                              ),
                              const SizedBox(width: 40),
                              IconButton(
                                icon: Icon(
                                  _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 80,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              const SizedBox(width: 40),
                              IconButton(
                                icon: const Icon(Icons.forward_10, color: Colors.white, size: 40),
                                onPressed: () => _seekRelative(10),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              colors: const VideoProgressColors(playedColor: Colors.redAccent, bufferedColor: Colors.white24, backgroundColor: Colors.grey),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(_videoController!.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(_formatDuration(_videoController!.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    } else if (mediaType == 'image') {
      final url = widget.media['url'] ?? widget.media['file'];
      if (url == null) return Container(height: 250, color: Colors.black26);
      return FutureBuilder<String?>(
        future: MediaCacheService.getCachedFilePath(url),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.file(File(snapshot.data!), fit: BoxFit.cover, width: double.infinity, height: 250);
          }
          return Image.network(url, fit: BoxFit.cover, width: double.infinity, height: 250);
        }
      );
    } else if (mediaType == 'audio') {
      if (_errorMessage != null) {
        return Container(
          height: 150,
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }
      if (_videoController == null || !_videoController!.value.isInitialized) {
        return Container(height: 150, color: Colors.black26, child: const Center(child: CircularProgressIndicator()));
      }
      return Container(
        height: 180,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          image: DecorationImage(image: AssetImage('assets/images/audio_wave.png'), opacity: 0.1, repeat: ImageRepeat.repeatX),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 48, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.replay_10, color: Colors.white), onPressed: () => _seekRelative(-10)),
                IconButton(
                  iconSize: 56,
                  icon: Icon(_videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white),
                  onPressed: _togglePlayPause,
                ),
                IconButton(icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _seekRelative(10)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: const VideoProgressColors(playedColor: Colors.blueAccent, bufferedColor: Colors.white10, backgroundColor: Colors.white24),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(_formatDuration(_videoController!.value.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                   Text(_formatDuration(_videoController!.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (mediaType == 'text') {
       return Container(
         padding: const EdgeInsets.all(20),
         constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
         width: double.infinity,
         color: const Color(0xFF0F172A),
         child: SingleChildScrollView(
           child: Text(
             widget.media['content'] ?? 'No content available.',
             style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
           ),
         ),
       );
    } else {
       return Container(
         height: 150, width: double.infinity, color: Colors.blueGrey.shade900,
         child: const Center(child: Icon(Icons.insert_drive_file, size: 64, color: Colors.white54)),
       );
    }
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _InteractionButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class _InlineCommentsSection extends StatefulWidget {
  final int mediaId;
  final List<dynamic> initialComments;

  const _InlineCommentsSection({required this.mediaId, required this.initialComments});

  @override
  State<_InlineCommentsSection> createState() => _InlineCommentsSectionState();
}

class _InlineCommentsSectionState extends State<_InlineCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  late List<dynamic> _comments;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.initialComments);
    if (_comments.length < 3) {
      _hasMore = false;
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await RecoveryService.getComments(widget.mediaId, page: _currentPage);
      final results = response['results'] as List<dynamic>? ?? [];
      
      setState(() {
        if (_currentPage == 1) {
             _comments = results;
        } else {
             _comments.addAll(results);
        }
        _hasMore = response['next'] != null;
        if (_hasMore) _currentPage++;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final content = _commentController.text.trim();
    _commentController.clear();
    try {
      await RecoveryService.postComment(widget.mediaId, content);
      setState(() {
        _comments.insert(0, {
          'user': 'You', 
          'content': content, 
          'created_at': DateTime.now().toString()
        });
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // Input Field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: _postComment),
            ],
          ),
          const SizedBox(height: 16),
          // Comments list
          if (_comments.isEmpty)
            const Text("No comments yet.", style: TextStyle(color: Colors.white54))
          else
            ..._comments.map((comment) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blueGrey,
                      child: Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['user'] ?? 'User',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(comment['content'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          if (_hasMore)
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _loadMoreComments,
                child: _isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text("Load more comments", style: TextStyle(color: Colors.blueAccent)),
              ),
            ),
        ],
      ),
    );
  }
}
