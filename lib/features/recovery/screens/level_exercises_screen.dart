import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/starry_background.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/core/widgets/celebration_dialog.dart';
import 'package:whiteapp/features/rewards/widgets/badge_earned_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _exercisesFuture = RecoveryService.getExercises(widget.levelId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          _showLevelCompletionDialog(response);
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

  void _showLevelCompletionDialog(Map<String, dynamic> result) {
    final unlockedChallenge = result['unlocked_challenge'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CelebrationDialog(
        title: "Level Completed!",
        message: "Great job! You've completed all exercises for this level.",
        buttonText: "Back to Levels",
        onContinue: () {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to LevelDetail
          Navigator.pop(context); // Go back to LevelList
        },
        extraContent: unlockedChallenge != null ? Column(
          children: [
             const Text(
               "New Challenge Unlocked:",
               style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               unlockedChallenge['title'],
               style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
             Text(
               unlockedChallenge['description'],
               style: const TextStyle(color: Colors.white70),
               textAlign: TextAlign.center,
             ),
          ]
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
              final total = exercises.length;
              final progress = (total > 0) ? (_currentPage + 1) / total : 0.0;

              return Column(
                children: [
                   // Progress Bar
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                     child: Column(
                       children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(
                               "Progress",
                               style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                             ),
                             Text(
                               "${_currentPage + 1} of $total",
                               style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         ClipRRect(
                           borderRadius: BorderRadius.circular(10),
                           child: LinearProgressIndicator(
                             value: progress,
                             minHeight: 6,
                             backgroundColor: Colors.white10,
                             color: Theme.of(context).primaryColor,
                           ),
                         ),
                       ],
                     ),
                   ),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: total,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        final exerciseId = exercise['id'];
                        final type = exercise['type'] ?? 'text';
                        final question = exercise['question'] ?? '';
                        final choices = (exercise['choices'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Exercise ${index + 1}",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                question,
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 18,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              if (type == 'text')
                                _buildTextField(exerciseId)
                              else if (type == 'multiple-choice')
                                _buildMultipleChoice(exerciseId, choices)
                              else
                                const Text("Unsupported exercise type", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Navigation Buttons
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          TextButton.icon(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text("Previous"),
                            style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          )
                        else
                          const SizedBox.shrink(),
                        
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _handleNext(exercises),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                _currentPage == total - 1 ? "Finish & Submit" : "Next",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(int exerciseId) {
    return TextField(
      maxLines: 5,
      style: const TextStyle(color: Colors.white),
      onChanged: (value) {
        _answers[exerciseId] = value;
      },
      controller: TextEditingController(text: _answers[exerciseId])..selection = TextSelection.collapsed(offset: (_answers[exerciseId] ?? "").length),
      decoration: InputDecoration(
        hintText: "Type your answer here...",
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildMultipleChoice(int exerciseId, List<String> choices) {
    return Column(
      children: choices.map((choice) {
        final isSelected = _answers[exerciseId] == choice;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                _answers[exerciseId] = choice;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.white10,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.white24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      choice,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleNext(List<dynamic> exercises) async {
    final currentExercise = exercises[_currentPage];
    final answer = _answers[currentExercise['id']];

    if (answer == null || answer.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide an answer first.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await RecoveryService.submitExercise(currentExercise['id'], answer);
      
      if (response['level_completed'] == true) {
         if (mounted) _showLevelCompletionDialog(response);
      } else if (_currentPage < exercises.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Last exercise but level not completed? This shouldn't happen if it's the last one.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("All exercises submitted!")),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
