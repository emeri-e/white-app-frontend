import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/recovery/screens/level_list_screen.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';

class ProgramListScreen extends StatefulWidget {
  static const String id = 'program_list_screen';

  const ProgramListScreen({super.key});

  @override
  State<ProgramListScreen> createState() => _ProgramListScreenState();
}

class _ProgramListScreenState extends State<ProgramListScreen> {
  late Future<List<dynamic>> _programsFuture;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _programsFuture = RecoveryService.getPrograms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Therapeutic Programs',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _programsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No programs found.', style: TextStyle(color: Colors.white)));
                    }

                    final allPrograms = snapshot.data!;
                    final filteredPrograms = _selectedCategory == 'all'
                        ? allPrograms
                        : allPrograms.where((p) => p['category'] == _selectedCategory).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildCategoryFilter('all', 'All Programs'),
                              const SizedBox(width: 8),
                              _buildCategoryFilter('addiction', 'Addiction Recovery'),
                              const SizedBox(width: 8),
                              _buildCategoryFilter('mental_health', 'Mental Health'),
                              const SizedBox(width: 8),
                              _buildCategoryFilter('personal_growth', 'Personal Growth'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: filteredPrograms.isEmpty 
                              ? const Center(child: Text('No programs match this category.', style: TextStyle(color: Colors.white70)))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: filteredPrograms.length,
                                  itemBuilder: (context, index) {
                                    final program = filteredPrograms[index];
                                    return _ProgramCard(
                                      program: program,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LevelListScreen(programId: program['id']),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(String value, String label) {
    bool isSelected = _selectedCategory == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = value);
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final VoidCallback onTap;

  const _ProgramCard({
    required this.program,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = program['title'] ?? 'Untitled Program';
    final description = program['description'] ?? 'No description available.';
    final coverImage = program['cover_image'];
    final difficulty = program['difficulty'] ?? 'beginner';
    final estimatedDuration = program['estimated_duration_hours']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0,4))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverImage != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  coverImage,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140, color: Colors.blueGrey,
                    child: const Icon(Icons.broken_image, size: 48, color: Colors.white54),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      _buildDifficultyBadge(difficulty, context),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.white54, size: 16),
                      const SizedBox(width: 4),
                      Text('$estimatedDuration hours', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      Icon(Icons.play_circle_fill_rounded, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Start',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty, BuildContext context) {
    Color color;
    switch (difficulty) {
      case 'beginner': color = Colors.green; break;
      case 'intermediate': color = Colors.orange; break;
      case 'advanced': color = Colors.redAccent; break;
      default: color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
