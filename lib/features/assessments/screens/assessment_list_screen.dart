import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/assessments/models/assessment.dart';
import 'package:whiteapp/features/assessments/services/assessment_service.dart';
import 'package:whiteapp/features/assessments/screens/assessment_detail_screen.dart';
import 'package:whiteapp/features/assessments/screens/assessment_history_screen.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class AssessmentListScreen extends StatefulWidget {
  static const String id = 'assessment_list_screen';
  const AssessmentListScreen({super.key});

  @override
  State<AssessmentListScreen> createState() => _AssessmentListScreenState();
}

class _AssessmentListScreenState extends State<AssessmentListScreen> {
  late Future<List<Map<String, dynamic>>> _assessmentsFuture;

  @override
  void initState() {
    super.initState();
    _assessmentsFuture = AssessmentService.getPendingAssessments();
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blueAccent;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }
  
  IconData _getIcon(String? name) {
    switch (name) {
      case 'mood_bad': return Icons.mood_bad;
      case 'waves': return Icons.waves;
      case 'sentiment_satisfied': return Icons.sentiment_satisfied;
      case 'restaurant': return Icons.restaurant;
      default: return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Assessments', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssessmentHistoryScreen()),
              );
            },
            tooltip: 'View History',
          ),
        ],
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _assessmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, size: 64, color: Colors.white24),
                    const SizedBox(height: 16),
                    Text(
                      'No pending assessments',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later or view your results.',
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AssessmentHistoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('View Result History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            final assessments = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: assessments.length,
              itemBuilder: (context, index) {
                final assessment = assessments[index];
                final color = _hexToColor(assessment['color_hex']);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.white.withOpacity(0.05),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: color.withOpacity(0.2)),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssessmentDetailScreen(assessmentId: assessment['id']),
                        ),
                      ).then((_) {
                        setState(() {
                          _assessmentsFuture = AssessmentService.getPendingAssessments();
                        });
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_getIcon(assessment['icon_name']), color: color, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assessment['title'] ?? 'Assessment',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  assessment['description'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
