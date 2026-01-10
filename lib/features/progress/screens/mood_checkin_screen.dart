import 'package:flutter/material.dart';
import 'package:whiteapp/features/progress/models/mood_entry.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class MoodCheckinScreen extends StatefulWidget {
  const MoodCheckinScreen({Key? key}) : super(key: key);

  @override
  _MoodCheckinScreenState createState() => _MoodCheckinScreenState();
}

class _MoodCheckinScreenState extends State<MoodCheckinScreen> {
  String? _selectedPrimaryEmotion;
  String? _selectedSecondaryEmotion;
  double _intensity = 5.0;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _primaryEmotions = [
    "Happy", "Anxious", "Depressed", "Calm", "Grateful", 
    "Angry", "Fearful", "Disgusted", "Surprised", "Neutral"
  ];

  Future<void> _submit() async {
    if (_selectedPrimaryEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select an emotion")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final entry = MoodEntry(
        date: DateTime.now().toIso8601String().split('T')[0],
        primaryEmotion: _selectedPrimaryEmotion!.toLowerCase(),
        secondaryEmotion: _selectedSecondaryEmotion,
        intensity: _intensity.toInt(),
        note: _noteController.text,
      );

      await ProgressService.logMood(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Mood logged successfully")),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mood Check-in"),
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "How are you feeling?",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _primaryEmotions.map((emotion) {
                final isSelected = _selectedPrimaryEmotion == emotion;
                return ChoiceChip(
                  label: Text(emotion),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPrimaryEmotion = selected ? emotion : null;
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            Text(
              "Intensity (1-10): ${_intensity.toInt()}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _intensity,
              min: 1,
              max: 10,
              divisions: 9,
              label: _intensity.toInt().toString(),
              onChanged: (value) {
                setState(() {
                  _intensity = value;
                });
              },
            ),
            SizedBox(height: 24),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: "Journal (Optional)",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting 
                    ? CircularProgressIndicator(color: Colors.white) 
                    : Text("Log Mood"),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
