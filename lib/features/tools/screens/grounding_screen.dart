import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/tools/models/grounding_exercise.dart';
import 'package:whiteapp/features/tools/services/tools_service.dart';
import 'package:whiteapp/features/tools/widgets/grounding_step_card.dart';

class GroundingScreen extends StatefulWidget {
  static const String id = 'grounding_screen';

  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  bool _isLoading = true;
  GroundingExercise? _exercise;
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isCompleted = false;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _loadExercise();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExercise() async {
    try {
      final exercises = await ToolsService.getGroundingExercises();
      if (exercises.isNotEmpty) {
        setState(() {
          _exercise = exercises.first; // Grab the first active grounding exercise (e.g. 5-4-3-2-1)
          _isLoading = false;
          _sessionStart = DateTime.now();
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load grounding tool: $e')),
        );
      }
    }
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    
    if (_exercise == null) return;
    
    if (_currentIndex < _exercise!.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSession();
    }
  }

  Future<void> _completeSession() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isCompleted = true;
    });

    if (_exercise != null && _sessionStart != null) {
      final duration = DateTime.now().difference(_sessionStart!).inSeconds;
      try {
        await ToolsService.logToolUsage(
          toolType: 'grounding',
          toolConfigId: _exercise!.id,
          durationSeconds: duration,
          completed: true,
        );
      } catch (e) {
        debugPrint("Error logging grounding usage: $e");
      }
    }
  }

  Color _getThemeColor(int index) {
    // Soothing color palette that shifts per step
    const colors = [
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.purpleAccent,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Grounding',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _exercise == null
                ? const Center(child: Text("No grounding exercise configured.", style: TextStyle(color: Colors.white)))
                : _isCompleted
                    ? _buildCompletionState()
                    : _buildWalkthrough(),
      ),
    );
  }

  Widget _buildWalkthrough() {
    final stepsCount = _exercise!.steps.length;

    return Column(
      children: [
        // Progress Dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(stepsCount, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? _getThemeColor(_currentIndex)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
        
        // Page View
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Force user to use "Continue" button
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: stepsCount,
            itemBuilder: (context, index) {
              final step = _exercise!.steps[index];
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: GroundingStepCard(
                  step: step,
                  themeColor: _getThemeColor(index),
                  onNext: _nextStep,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.tealAccent.withOpacity(0.1),
            ),
            child: const Icon(Icons.psychology, size: 80, color: Colors.tealAccent),
          ),
          const SizedBox(height: 40),
          Text(
            "You are here.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "You have brought your mind back to the present moment. Take a deep breath and carry this calmness with you.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Done', style: GoogleFonts.outfit(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
