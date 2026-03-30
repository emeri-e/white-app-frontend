import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/starry_background.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/features/recovery/screens/level_exercises_screen.dart';
import 'package:whiteapp/features/recovery/widgets/media_display_widget.dart';
import 'package:whiteapp/features/rewards/widgets/badge_earned_dialog.dart';
import 'package:whiteapp/core/widgets/celebration_dialog.dart';

class LevelDetailScreen extends StatefulWidget {
  static const String id = 'level_detail_screen';
  final int levelId;

  const LevelDetailScreen({super.key, required this.levelId});

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> {
  late Future<Map<String, dynamic>> _levelFuture;
  Set<int> _completedMediaIds = {};
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _levelFuture = RecoveryService.getLevelDetails(widget.levelId);
  }

  void _onMediaComplete(int mediaId) async {
    if (_completedMediaIds.contains(mediaId)) return;
    
    setState(() {
      _completedMediaIds.add(mediaId);
    });

    try {
      await RecoveryService.markMediaComplete(mediaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Media Completed!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
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
      builder: (context) => CelebrationDialog(
        title: "Level Completed!",
        message: "Great job! You've completed this level.",
        buttonText: "Continue",
        onContinue: () {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to level list
        },
        extraContent: unlockedChallenge != null ? Column(
          children: [
            const Text(
              "New Challenge Unlocked:",
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              unlockedChallenge['title'],
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ) : null,
      ),
    ).then((_) {
      if (result['new_badges'] != null && (result['new_badges'] as List).isNotEmpty) {
        if (context.mounted) showBadgeEarnedDialog(context, result['new_badges']);
      }
    });
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
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData) {
                return const Center(child: Text('Level not found.', style: TextStyle(color: Colors.white)));
              }

              final level = snapshot.data!;
              final mediaList = level['media'] as List<dynamic>? ?? [];
              
              if (_completedMediaIds.isEmpty) {
                 for (var media in mediaList) {
                   if (media['is_completed'] == true) {
                     _completedMediaIds.add(media['id']);
                   }
                 }
              }

              if (mediaList.isEmpty) {
                 return _buildNoMediaView(level);
              }

              // Ensure index bounds
              if (_currentMediaIndex >= mediaList.length) {
                _currentMediaIndex = mediaList.length - 1;
              }

              final currentMedia = mediaList[_currentMediaIndex];
              final isCurrentCompleted = _completedMediaIds.contains(currentMedia['id']) || currentMedia['media_type'] != 'video';
              final isLastMedia = _currentMediaIndex == mediaList.length - 1;

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
                    
                    // Display step indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(mediaList.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentMediaIndex == index ? Colors.blueAccent : Colors.white24,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Display current media
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: MediaDisplayWidget(
                        key: ValueKey(currentMedia['id']),
                        media: currentMedia,
                        onMediaCompleted: _onMediaComplete,
                      ),
                    ),

                    const SizedBox(height: 30),
                    
                    // Navigation Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isCurrentCompleted ? Colors.blueAccent : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isCurrentCompleted ? () async {
                          if (!isLastMedia) {
                            setState(() {
                              _currentMediaIndex++;
                            });
                          } else {
                            // Finish Level or Go to Exercises
                            _proceedToExercisesOrComplete();
                          }
                        } : null,
                        child: Text(
                          isLastMedia ? "Continue to Exercises" : "Next",
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

  Widget _buildNoMediaView(Map<String, dynamic> level) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              level['title'] ?? 'Untitled Level',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "No media content for this level.",
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent),
                onPressed: _proceedToExercisesOrComplete,
                child: const Text("Continue to Exercises", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              )
            )
          ]
        )
      );
  }

  Future<void> _proceedToExercisesOrComplete() async {
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
        final result = await RecoveryService.markLevelComplete(widget.levelId);
        if (context.mounted) {
          _showCompletionDialog(context, result);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}


