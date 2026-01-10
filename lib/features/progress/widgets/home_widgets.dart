import 'package:flutter/material.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'package:whiteapp/features/progress/models/mood_entry.dart';
import 'package:whiteapp/features/progress/models/relapse_entry.dart';

class MiniStreakWidget extends StatelessWidget {
  const MiniStreakWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ProfileService.getProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final profile = snapshot.data!;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.cleanDays} Days',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Clean Streak',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class QuickLogWidget extends StatelessWidget {
  const QuickLogWidget({super.key});

  void _showRelapseDialog(BuildContext context) {
    final causeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Relapse'),
        content: TextField(
          controller: causeController,
          decoration: const InputDecoration(labelText: 'Cause / Trigger'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await ProgressService.logRelapse(RelapseEntry(
                  date: DateTime.now().toIso8601String(),
                  cause: causeController.text,
                  emotions: 'Reported via Quick Log',
                ));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relapse logged. Streak reset.')));
                }
              } catch (e) {
                debugPrint('Error: $e');
              }
            },
            child: const Text('Submit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showToolDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Tool Used'),
        children: [
          _toolOption(context, 'Meditation', 'meditation'),
          _toolOption(context, 'Journaling', 'journaling'),
          _toolOption(context, 'Prayer', 'prayer'),
          _toolOption(context, 'Emergency Toolkit', 'emergency_toolkit'),
        ],
      ),
    );
  }

  Widget _toolOption(BuildContext context, String label, String type) {
    return SimpleDialogOption(
      onPressed: () async {
        try {
          await ProgressService.logToolUsage(type, 600); // Default 10 mins
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label logged!')));
          }
        } catch (e) {
          debugPrint('Error: $e');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showToolDialog(context),
            icon: const Icon(Icons.build, size: 16),
            label: const Text('Log Tool'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.8),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showRelapseDialog(context),
            icon: const Icon(Icons.warning, size: 16),
            label: const Text('Relapse'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class MoodCheckInWidget extends StatelessWidget {
  const MoodCheckInWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(0.5), Colors.deepPurple.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How are you feeling?',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _moodButton(context, '😊', 'happy', 8),
              _moodButton(context, '😐', 'neutral', 5),
              _moodButton(context, '😔', 'depressed', 3),
              _moodButton(context, '😰', 'anxious', 3),
              _moodButton(context, '😡', 'angry', 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moodButton(BuildContext context, String emoji, String emotion, int intensity) {
    return InkWell(
      onTap: () async {
        try {
          await ProgressService.logMood(MoodEntry(
            date: DateTime.now().toIso8601String().split('T')[0],
            primaryEmotion: emotion,
            intensity: intensity,
            note: 'Quick check-in',
          ));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mood logged!')));
          }
        } catch (e) {
          debugPrint('Error: $e');
        }
      },
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 32),
      ),
    );
  }
}
