import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/tools/models/grounding_exercise.dart';

class GroundingStepCard extends StatefulWidget {
  final GroundingStep step;
  final VoidCallback onNext;
  final Color themeColor;

  const GroundingStepCard({
    super.key,
    required this.step,
    required this.onNext,
    required this.themeColor,
  });

  @override
  State<GroundingStepCard> createState() => _GroundingStepCardState();
}

class _GroundingStepCardState extends State<GroundingStepCard> {
  late List<TextEditingController> _controllers;
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.step.count,
      (index) => TextEditingController()..addListener(_checkInputs),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _checkInputs() {
    bool allFilled = true;
    for (var controller in _controllers) {
      if (controller.text.trim().isEmpty) {
        allFilled = false;
        break;
      }
    }
    if (allFilled != _canProceed) {
      setState(() {
        _canProceed = allFilled;
      });
    }
  }

  IconData _getIconForSense(String sense) {
    switch (sense.toLowerCase()) {
      case 'see':
        return Icons.visibility;
      case 'touch':
        return Icons.pan_tool;
      case 'hear':
        return Icons.hearing;
      case 'smell':
        return Icons.air; // Using air as an approximation for smell
      case 'taste':
        return Icons.restaurant;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.themeColor.withOpacity(0.1),
            ),
            child: Icon(
              _getIconForSense(widget.step.sense),
              size: 80,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 32),

          // Prompts
          Text(
            widget.step.promptText,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (widget.step.helperText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.step.helperText,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Input Fields
          if (widget.step.allowTypedInput)
            ...List.generate(widget.step.count, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  controller: _controllers[index],
                  style: GoogleFonts.outfit(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Item ${index + 1}...',
                    hintStyle: GoogleFonts.outfit(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: widget.themeColor, width: 2),
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // Next Button
          ElevatedButton(
            onPressed: (!widget.step.allowTypedInput || _canProceed) ? widget.onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              foregroundColor: Colors.black87,
              disabledBackgroundColor: Colors.white.withOpacity(0.1),
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
