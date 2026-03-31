import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/assessments/models/assessment.dart';
import 'package:whiteapp/features/assessments/services/assessment_service.dart';
import 'package:whiteapp/features/assessments/screens/assessment_result_screen.dart';

class AssessmentDetailScreen extends StatefulWidget {
  final int assessmentId;
  const AssessmentDetailScreen({super.key, required this.assessmentId});

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  late Future<Assessment> _assessmentFuture;
  final Map<int, int> _responses = {}; // QuestionID -> OptionValue
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _assessmentFuture = AssessmentService.getAssessmentDetail(widget.assessmentId);
  }

  void _selectOption(int questionId, int value, int totalQuestions) {
    setState(() {
      _responses[questionId] = value;
      if (_currentQuestionIndex < totalQuestions - 1) {
        _currentQuestionIndex++;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await AssessmentService.submitAssessment(widget.assessmentId, _responses);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AssessmentResultScreen(result: result)),
        );
        if (mounted) {
          Navigator.pop(context, true); // Pop back to HomeScreen
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment')),
      body: FutureBuilder<Assessment>(
        future: _assessmentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Assessment not found'));
          }

          final assessment = snapshot.data!;
          final questions = assessment.questions ?? [];
          
          if (questions.isEmpty) {
            return const Center(child: Text('No questions in this assessment.'));
          }

          final currentQuestion = questions[_currentQuestionIndex];
          final progress = (_currentQuestionIndex + 1) / questions.length;

          return Column(
            children: [
              LinearProgressIndicator(value: progress, minHeight: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                        style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentQuestion.text,
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      ...currentQuestion.options.map((option) {
                        final isSelected = _responses[currentQuestion.id] == option.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: InkWell(
                            onTap: () => _selectOption(currentQuestion.id, option.value, questions.length),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                gradient: isSelected ? LinearGradient(
                                  colors: [Theme.of(context).primaryColor.withValues(alpha: 0.2), Theme.of(context).primaryColor.withValues(alpha: 0.05)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ) : LinearGradient(
                                  colors: [Colors.white24, Colors.white12],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).primaryColor : Colors.white24,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ] : [],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.text,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor, size: 28),
                                  if (!isSelected)
                                    const Icon(Icons.circle_outlined, color: Colors.white54, size: 28),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentQuestionIndex > 0)
                      TextButton(
                        onPressed: () => setState(() => _currentQuestionIndex--),
                        child: const Text('Previous'),
                      )
                    else
                      const SizedBox.shrink(),
                      
                    if (_currentQuestionIndex == questions.length - 1)
                      ElevatedButton(
                        onPressed: _responses.length == questions.length && !_isSubmitting ? _submit : null,
                        child: _isSubmitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Text('Submit'),
                      )
                    else
                      const SizedBox.shrink(), // Auto-advance handles next, or user can tap option
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
