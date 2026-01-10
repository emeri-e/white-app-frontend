import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/starry_background.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';

class LevelExercisesScreen extends StatefulWidget {
  static const String id = 'level_exercises_screen';
  final int levelId;

  const LevelExercisesScreen({super.key, required this.levelId});

  @override
  State<LevelExercisesScreen> createState() => _LevelExercisesScreenState();
}

class _LevelExercisesScreenState extends State<LevelExercisesScreen> {
  late Future<List<dynamic>> _exercisesFuture;
  final Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _exercisesFuture = RecoveryService.getExercises(widget.levelId);
  }

  Future<void> _submitExercise(int exerciseId) async {
    final answer = _answers[exerciseId];
    if (answer == null || answer.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an answer first.")),
      );
      return;
    }

    try {
      final response = await RecoveryService.submitExercise(exerciseId, answer);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exercise saved!")),
        );
        
        if (response['level_completed'] == true) {
          _showLevelCompletionDialog(response['unlocked_challenge']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting exercise: $e")),
        );
      }
    }
  }

  void _showLevelCompletionDialog(Map<String, dynamic>? unlockedChallenge) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Level Completed!", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Great job! You've completed all exercises for this level.",
              style: TextStyle(color: Colors.white70),
            ),
            if (unlockedChallenge != null) ...[
              const SizedBox(height: 16),
              const Text(
                "New Challenge Unlocked:",
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                unlockedChallenge['title'],
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                unlockedChallenge['description'],
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to LevelDetail
              Navigator.pop(context); // Go back to LevelList
            },
            child: const Text("Back to Levels"),
          ),
          if (unlockedChallenge != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () {
                // Navigate to challenges tab or specific challenge screen
                // For now, just pop back to home/dashboard
                 Navigator.pop(context); // Close dialog
                 Navigator.pop(context); // Go back to LevelDetail
                 Navigator.pop(context); // Go back to LevelList
                 // Ideally navigate to ChallengeListScreen
              },
              child: const Text("View Challenge", style: TextStyle(color: Colors.black)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: StarryBackground(
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _exercisesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No exercises found for this level.', style: TextStyle(color: Colors.white)));
              }

              final exercises = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  final exerciseId = exercise['id'];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Exercise ${index + 1}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          exercise['question'] ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            _answers[exerciseId] = value;
                          },
                          decoration: InputDecoration(
                            hintText: "Type your answer here...",
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _submitExercise(exerciseId),
                          child: const Text("Submit"),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
