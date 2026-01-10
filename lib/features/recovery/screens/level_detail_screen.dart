import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:whiteapp/core/widgets/starry_background.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/features/recovery/screens/level_exercises_screen.dart';

class LevelDetailScreen extends StatefulWidget {
  static const String id = 'level_detail_screen';
  final int levelId;

  const LevelDetailScreen({super.key, required this.levelId});

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> {
  late Future<Map<String, dynamic>> _levelFuture;
  VideoPlayerController? _videoController;
  bool _isVideoCompleted = false;
  int? _currentMediaId;

  @override
  void initState() {
    super.initState();
    _levelFuture = RecoveryService.getLevelDetails(widget.levelId);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(String url, int mediaId, bool isCompleted) async {
    if (_videoController != null && _currentMediaId == mediaId) return;
    
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    _currentMediaId = mediaId;
    _isVideoCompleted = isCompleted;
    
    await _videoController!.initialize();
    
    _videoController!.addListener(() {
      if (_videoController!.value.position >= _videoController!.value.duration && !_isVideoCompleted) {
        _onVideoComplete();
      }
      setState(() {});
    });
    
    setState(() {});
  }

  void _onVideoComplete() async {
    if (_isVideoCompleted || _currentMediaId == null) return;
    
    setState(() {
      _isVideoCompleted = true;
    });

    try {
      await RecoveryService.markMediaComplete(_currentMediaId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Video Completed! You can now proceed."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error marking media complete: $e");
    }
  }

  void _showCompletionDialog(BuildContext context, Map<String, dynamic> result) {
    final unlockedChallenge = result['unlocked_challenge'];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Level Completed!", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            const Text(
              "Great job! You've completed this level.",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (unlockedChallenge != null) ...[
              const SizedBox(height: 20),
              const Text(
                "New Challenge Unlocked:",
                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                unlockedChallenge['title'],
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to level list
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Level Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: StarryBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _levelFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData) {
                return const Center(child: Text('Level not found.', style: TextStyle(color: Colors.white)));
              }

              final level = snapshot.data!;
              final mediaList = level['media'] as List<dynamic>? ?? [];
              
              // Find first video to play
              final videoMedia = mediaList.firstWhere(
                (m) => m['media_type'] == 'video',
                orElse: () => null,
              );

              if (videoMedia != null && _videoController == null) {
                _initializeVideo(
                  videoMedia['url'] ?? videoMedia['file'], 
                  videoMedia['id'],
                  videoMedia['is_completed'] ?? false
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level['title'] ?? 'Untitled Level',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      level['description'] ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 30),
                    
                    if (_videoController != null && _videoController!.value.isInitialized)
                      Column(
                        children: [
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                VideoPlayer(_videoController!),
                                _ControlsOverlay(controller: _videoController!),
                                VideoProgressIndicator(_videoController!, allowScrubbing: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_isVideoCompleted)
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text("Video Watched", style: TextStyle(color: Colors.green)),
                              ],
                            ),
                        ],
                      )
                    else if (videoMedia != null)
                      const Center(child: CircularProgressIndicator())
                    else
                      const SizedBox.shrink(),

                    // Display other media (PDFs, etc.)
                    ...mediaList.where((m) => m['media_type'] != 'video').map((media) {
                      return ListTile(
                        leading: Icon(
                          media['media_type'] == 'pdf' ? Icons.picture_as_pdf : Icons.insert_drive_file,
                          color: Colors.white,
                        ),
                        title: Text(media['title'], style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.download, color: Colors.white),
                          onPressed: () {
                            // TODO: Implement download logic
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Download started...")),
                            );
                          },
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 30),
                    
                    // Button to proceed
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _isVideoCompleted ? Colors.blueAccent : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isVideoCompleted ? () async {
                          // Check if there are exercises
                          try {
                            final exercises = await RecoveryService.getExercises(widget.levelId);
                            if (exercises.isNotEmpty) {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LevelExercisesScreen(levelId: widget.levelId),
                                  ),
                                );
                              }
                            } else {
                              // No exercises, mark complete directly
                              final result = await RecoveryService.markLevelComplete(widget.levelId);
                              if (context.mounted) {
                                _showCompletionDialog(context, result);
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                        } : null,
                        child: Text(
                          _isVideoCompleted ? "Continue" : "Watch Video to Continue",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
        Align(
          alignment: Alignment.topRight,
          child: PopupMenuButton<double>(
            initialValue: controller.value.playbackSpeed,
            tooltip: 'Playback speed',
            onSelected: (double speed) {
              controller.setPlaybackSpeed(speed);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<double>>[
                for (final double speed in [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0])
                  PopupMenuItem<double>(
                    value: speed,
                    child: Text('${speed}x'),
                  )
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text('${controller.value.playbackSpeed}x', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}
