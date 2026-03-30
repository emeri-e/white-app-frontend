import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/assessments/models/assessment.dart';
import 'package:whiteapp/features/rewards/widgets/badge_earned_dialog.dart';

class AssessmentResultScreen extends StatelessWidget {
  final UserAssessmentResult result;
  const AssessmentResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // Show badge earned dialog if any
    if (result.newBadges != null && result.newBadges!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showBadgeEarnedDialog(context, result.newBadges!);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'Assessment Complete',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                result.assessmentTitle,
                style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Score',
                      style: GoogleFonts.outfit(fontSize: 16, color: Colors.blue[800]),
                    ),
                    Text(
                      result.score.toStringAsFixed(0),
                      style: GoogleFonts.outfit(
                        fontSize: 64, 
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      result.resultLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (result.subscaleResults != null && result.subscaleResults!.isNotEmpty) ...[
                Text(
                  'Subscale Scores',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...result.subscaleResults!.map((sub) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sub.domain.toUpperCase(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue[800]),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            sub.score.toStringAsFixed(0),
                            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                          ),
                          if (sub.resultLabel.isNotEmpty)
                            Text(
                              sub.resultLabel,
                              style: GoogleFonts.outfit(fontSize: 14, color: Colors.blue[800]),
                            ),
                        ],
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
              ],
              if (result.responses != null && result.responses!.isNotEmpty) ...[
                Text(
                  'Response Breakdown',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...result.responses!.map((UserAssessmentResponse response) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        response.questionText,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your answer: ${response.optionText ?? response.value.toString()}',
                        style: GoogleFonts.outfit(color: Colors.black87),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 40),
              ],
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Done'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
