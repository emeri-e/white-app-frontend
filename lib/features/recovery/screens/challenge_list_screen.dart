import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/features/rewards/widgets/badge_earned_dialog.dart';
import 'package:whiteapp/core/widgets/celebration_dialog.dart';

class ChallengeListScreen extends StatefulWidget {
  static const String id = 'challenge_list_screen';

  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  final Set<int> _autoCompletingChallenges = {};

  Future<List<dynamic>> _fetchChallenges(String status) async {
    return RecoveryService.getChallenges(status: status);
  }

  void _checkAutoCompletions(List<dynamic> challenges) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var challenge in challenges) {
        final isCompleted = challenge['is_completed'] ?? false;
        final type = challenge['type'];
        final progressPercentage = (challenge['progress_percentage'] ?? 0.0).toDouble();

        if (type == 'time_based' && !isCompleted && progressPercentage >= 1.0) {
          final id = challenge['id'];
          if (!_autoCompletingChallenges.contains(id)) {
            _autoCompletingChallenges.add(id);
            _completeChallenge(challenge, context);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Challenges'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
            ],
            indicatorColor: Theme.of(context).primaryColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: AbstractBackground(
          scrollProgress: 1.0,
          child: SafeArea(
            child: TabBarView(
              children: [
                _buildChallengeList('available'),
                _buildChallengeList('completed'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeList(String status) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchChallenges(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No ${status == 'completed' ? 'completed' : 'active'} challenges found.', style: const TextStyle(color: Colors.white)));
        }

        final challenges = snapshot.data!;
        if (status == 'available') {
          _checkAutoCompletions(challenges);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            final isLocked = challenge['is_locked'] ?? false;
            final isCompleted = challenge['is_completed'] ?? false;
            final type = challenge['type'];
            final progressPercentage = (challenge['progress_percentage'] ?? 0.0).toDouble();
            final durationMinutes = challenge['duration_minutes'] ?? 0;
            final startedAt = challenge['started_at'];
            final tasks = challenge['tasks'] ?? [];
            final completedTasks = challenge['completed_tasks'] ?? [];
            final restarts = challenge['restarts'] as List? ?? [];
            
            return _ChallengeCard(
              title: challenge['title'] ?? 'Untitled Challenge',
              description: challenge['description'] ?? '',
              reward: '${challenge['gold_reward']} Gold',
              isCompleted: isCompleted,
              isLocked: isLocked,
              type: type,
              progressPercentage: progressPercentage,
              durationMinutes: durationMinutes,
              startedAt: startedAt,
              tasks: tasks,
              completedTasks: completedTasks,
              restarts: restarts,
              onStart: () async {
                 try {
                   await RecoveryService.startChallenge(challenge['id']);
                   setState(() {});
                 } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                 }
              },
              onTaskToggled: (taskId, isDone) async {
                 try {
                    final result = await RecoveryService.updateChallengeTask(challenge['id'], taskId, isDone);
                    setState(() {});
                    if (result['is_completed'] == true || (result['completed'] == true)) {
                      if (mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => CelebrationDialog(
                            title: "Challenge Completed!",
                            message: "You earned +${challenge['gold_reward']} Gold and +${challenge['gem_reward']} Gems!",
                            buttonText: "Awesome!",
                            icon: Icons.celebration,
                            onContinue: () => Navigator.pop(context),
                          ),
                        ).then((_) {
                            if (result['new_badges'] != null && (result['new_badges'] as List).isNotEmpty) {
                              if (mounted) showBadgeEarnedDialog(context, result['new_badges']);
                            }
                          });
                      }
                    }
                 } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                 }
              },
              onTap: () async {
                if (isLocked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Complete the previous level to unlock this challenge!")),
                  );
                } else if (!isCompleted) {
                  if (type == 'time_based') {
                    if (progressPercentage < 1.0) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("Keep going! Meet the time requirement to finish this challenge.")),
                       );
                    } else {
                      await _completeChallenge(challenge, context);
                    }
                  } else if (tasks.isEmpty) {
                    await _completeChallenge(challenge, context);
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _completeChallenge(Map<String, dynamic> challenge, BuildContext context) async {
    try {
      final result = await RecoveryService.markChallengeComplete(challenge['id']);
      setState(() {});
      if (mounted) {
        showDialog(
           context: context,
           barrierDismissible: false,
           builder: (context) => CelebrationDialog(
             title: "Challenge Completed!",
             message: "You earned +${challenge['gold_reward']} Gold and +${challenge['gem_reward']} Gems!",
             buttonText: "Awesome!",
             icon: Icons.celebration,
             onContinue: () => Navigator.pop(context),
           ),
        ).then((_) {
            if (result['new_badges'] != null && (result['new_badges'] as List).isNotEmpty) {
              if (mounted) showBadgeEarnedDialog(context, result['new_badges']);
            }
          });
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

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String description;
  final String reward;
  final bool isCompleted;
  final bool isLocked;
  final String type;
  final double progressPercentage;
  final int durationMinutes;
  final String? startedAt;
  final List<dynamic> tasks;
  final List<dynamic> completedTasks;
  final List<dynamic> restarts;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final Function(dynamic, bool) onTaskToggled;

  const _ChallengeCard({
    required this.title,
    required this.description,
    required this.reward,
    required this.isCompleted,
    required this.isLocked,
    required this.type,
    required this.progressPercentage,
    required this.durationMinutes,
    required this.startedAt,
    required this.tasks,
    required this.completedTasks,
    required this.restarts,
    required this.onTap,
    required this.onStart,
    required this.onTaskToggled,
  });

  @override
  Widget build(BuildContext context) {
    int daysAgo = 0;
    if (startedAt != null) {
      final started = DateTime.parse(startedAt!);
      daysAgo = DateTime.now().difference(started).inDays;
    }

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          Row(
                            children: [
                              Text(
                                'Reward: $reward',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (restarts.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.refresh_rounded, color: Colors.orangeAccent, size: 10),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${restarts.length} restarts",
                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLocked && startedAt != null) ...[
                 const SizedBox(height: 12),
                 Text('Started ${daysAgo == 0 ? 'today' : '$daysAgo days ago'}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              if (!isLocked && !isCompleted && startedAt == null) ...[
                 const SizedBox(height: 16),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: onStart,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.blueAccent, 
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     child: const Text('Start Challenge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   ),
                 ),
              ] else if (!isLocked && !isCompleted && startedAt != null) ...[
                 if (type == 'time_based') ...[
                   const SizedBox(height: 16),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(
                         "${(progressPercentage * 100).toStringAsFixed(1)}%",
                         style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                       ),
                       Text(
                         "$durationMinutes mins total",
                         style: const TextStyle(color: Colors.white54, fontSize: 12),
                       ),
                     ],
                   ),
                   const SizedBox(height: 6),
                   LinearProgressIndicator(
                     value: progressPercentage,
                     backgroundColor: Colors.white10,
                     color: Colors.greenAccent,
                     minHeight: 8,
                     borderRadius: BorderRadius.circular(4),
                   ),
                 ] else if (type == 'other' && tasks.isNotEmpty) ...[
                   const SizedBox(height: 16),
                   Container(
                     decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: tasks.map((task) {
                         final taskId = task['id'];
                         final isDone = completedTasks.contains(taskId) || completedTasks.contains(taskId.toString());
                         return Theme(
                           data: ThemeData(unselectedWidgetColor: Colors.white54),
                           child: CheckboxListTile(
                             value: isDone,
                             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                             dense: true,
                             title: Text(task['text'] ?? '', style: TextStyle(color: isDone ? Colors.white54 : Colors.white, decoration: isDone ? TextDecoration.lineThrough : null)),
                             onChanged: (val) {
                                if (val != null) onTaskToggled(taskId, val);
                             },
                             activeColor: Colors.greenAccent,
                             checkColor: Colors.black,
                             controlAffinity: ListTileControlAffinity.leading,
                           ),
                         );
                       }).toList(),
                     ),
                   )
                 ]
              ],
            ],
          ),
        ),
      ),
    );
  }
}
