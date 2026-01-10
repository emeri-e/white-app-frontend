import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/recovery/screens/level_detail_screen.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';

class LevelListScreen extends StatefulWidget {
  static const String id = 'level_list_screen';
  final int programId;

  const LevelListScreen({super.key, required this.programId});

  @override
  State<LevelListScreen> createState() => _LevelListScreenState();
}

class _LevelListScreenState extends State<LevelListScreen> {
  late Future<List<dynamic>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _levelsFuture = RecoveryService.getLevels(widget.programId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Levels'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _levelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No levels found.', style: TextStyle(color: Colors.white)));
              }

              final levels = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: levels.length,
                itemBuilder: (context, index) {
                  final level = levels[index];
                  final isLocked = level['is_locked'] ?? false;
                  
                  return _LevelCard(
                    levelNumber: level['order'] ?? (index + 1),
                    title: level['title'] ?? 'Untitled Level',
                    description: level['description'] ?? '',
                    isLocked: isLocked,
                    onTap: () {
                      if (!isLocked) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LevelDetailScreen(levelId: level['id']),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Complete the previous challenge to unlock this level!")),
                        );
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
}

class _LevelCard extends StatelessWidget {
  final int levelNumber;
  final String title;
  final String description;
  final bool isLocked;
  final VoidCallback onTap;

  const _LevelCard({
    required this.levelNumber,
    required this.title,
    required this.description,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isLocked ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLocked ? Colors.white10 : Theme.of(context).primaryColor.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isLocked ? Colors.grey.withOpacity(0.2) : Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isLocked
                      ? const Icon(Icons.lock, color: Colors.white54)
                      : Text(
                          '$levelNumber',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
                            color: Colors.white38,
                          ),
                    ),
                  ],
                ),
              ),
              if (!isLocked)
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
