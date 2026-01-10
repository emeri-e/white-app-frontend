import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';

class ChallengeListScreen extends StatefulWidget {
  static const String id = 'challenge_list_screen';

  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  late Future<List<dynamic>> _challengesFuture;

  @override
  void initState() {
    super.initState();
    _challengesFuture = RecoveryService.getChallenges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _challengesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No challenges found.', style: TextStyle(color: Colors.white)));
              }

              final challenges = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: challenges.length,
                itemBuilder: (context, index) {
                  final challenge = challenges[index];
                  final isLocked = challenge['is_locked'] ?? false;
                  final isCompleted = challenge['is_completed'] ?? false;
                  
                  return _ChallengeCard(
                    title: challenge['title'] ?? 'Untitled Challenge',
                    description: challenge['description'] ?? '',
                    reward: '${challenge['gold_reward']} Gold',
                    isCompleted: isCompleted,
                    isLocked: isLocked,
                    onTap: () async {
                      if (isLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Complete the previous level to unlock this challenge!")),
                        );
                      } else if (!isCompleted) {
                        final durationMinutes = challenge['duration_minutes'] ?? 0;
                        if (durationMinutes > 0) {
                          // Time-based challenge
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => _ChallengeTimerDialog(
                              durationMinutes: durationMinutes,
                              onComplete: () async {
                                Navigator.pop(context); // Close dialog
                                await _completeChallenge(challenge, context);
                              },
                            ),
                          );
                        } else {
                          // Instant challenge
                          await _completeChallenge(challenge, context);
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }


  Future<void> _completeChallenge(Map<String, dynamic> challenge, BuildContext context) async {
    try {
      await RecoveryService.markChallengeComplete(challenge['id']);
      setState(() {
        _challengesFuture = RecoveryService.getChallenges();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Challenge Completed! +${challenge['gold_reward']} Gold, +${challenge['gem_reward']} Gems"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
}

class _ChallengeTimerDialog extends StatefulWidget {
  final int durationMinutes;
  final VoidCallback onComplete;

  const _ChallengeTimerDialog({
    required this.durationMinutes,
    required this.onComplete,
  });

  @override
  State<_ChallengeTimerDialog> createState() => _ChallengeTimerDialogState();
}

class _ChallengeTimerDialogState extends State<_ChallengeTimerDialog> {
  late int _remainingSeconds;
  late int _totalSeconds;
  bool _isPaused = false;
  
  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.durationMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_remainingSeconds > 0 && !_isPaused) {
        setState(() {
          _remainingSeconds--;
        });
        _startTimer();
      } else if (_remainingSeconds == 0) {
        widget.onComplete();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (_remainingSeconds / _totalSeconds);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Challenge in Progress", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            color: Colors.greenAccent,
            strokeWidth: 8,
          ),
          const SizedBox(height: 20),
          Text(
            _formatTime(_remainingSeconds),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Stay focused! Do not close this app.",
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Give Up", style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String description;
  final String reward;
  final bool isCompleted;
  final bool isLocked;
  final VoidCallback onTap;

  const _ChallengeCard({
    required this.title,
    required this.description,
    required this.reward,
    required this.isCompleted,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isLocked 
            ? Colors.white.withOpacity(0.05) 
            : (isCompleted ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked 
              ? Colors.white10 
              : (isCompleted ? Colors.green.withOpacity(0.5) : Colors.white10)
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLocked 
                      ? Colors.grey.withOpacity(0.2) 
                      : (isCompleted ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLocked ? Icons.lock : (isCompleted ? Icons.check : Icons.emoji_events),
                  color: isLocked ? Colors.white54 : (isCompleted ? Colors.green : Colors.orange),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isLocked ? Colors.white54 : Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isLocked ? Colors.white30 : Colors.white70,
                          ),
                    ),
                    if (!isLocked) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reward: $reward',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
