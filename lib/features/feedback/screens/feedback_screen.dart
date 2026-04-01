import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/feedback/services/feedback_service.dart';
import 'dart:ui';

class FeedbackScreen extends StatefulWidget {
  static const String id = 'feedback_screen';

  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _messageController = TextEditingController();
  String _selectedType = 'suggestion';
  bool _isSubmitting = false;

  final List<Map<String, String>> _types = [
    {'value': 'bug', 'label': 'Report a Bug', 'icon': 'bug_report_rounded'},
    {'value': 'suggestion', 'label': 'Suggestion', 'icon': 'lightbulb_rounded'},
    {'value': 'question', 'label': 'Question', 'icon': 'help_outline_rounded'},
    {'value': 'other', 'label': 'Other', 'icon': 'more_horiz_rounded'},
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'bug_report_rounded': return Icons.bug_report_rounded;
      case 'lightbulb_rounded': return Icons.lightbulb_rounded;
      case 'help_outline_rounded': return Icons.help_outline_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FeedbackService.submitFeedback(
        message: _messageController.text.trim(),
        type: _selectedType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Share Feedback', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How can we improve?',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Your feedback helps us make the app better for everyone in the recovery journey.',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('Feedback Category'),
              const SizedBox(height: 12),
              _buildTypeSelector(),
              
              const SizedBox(height: 32),
              _buildSectionHeader('Your Message'),
              const SizedBox(height: 12),
              _buildMessageInput(),

              const SizedBox(height: 48),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.5),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _types.map((type) {
        final isSelected = _selectedType == type['value'];
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type['value']!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getIcon(type['icon']!), size: 18, color: isSelected ? Colors.blueAccent : Colors.white38),
                const SizedBox(width: 8),
                Text(
                  type['label']!,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _messageController,
        maxLines: 6,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Tell us what is on your mind...',
          hintStyle: GoogleFonts.outfit(color: Colors.white24),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          shadowColor: Colors.blueAccent.withOpacity(0.3),
        ),
        child: _isSubmitting 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text('Submit Feedback', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
