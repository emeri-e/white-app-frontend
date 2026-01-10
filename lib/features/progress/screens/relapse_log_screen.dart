import 'package:flutter/material.dart';
import 'package:whiteapp/features/progress/models/relapse_entry.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class RelapseLogScreen extends StatefulWidget {
  const RelapseLogScreen({Key? key}) : super(key: key);

  @override
  _RelapseLogScreenState createState() => _RelapseLogScreenState();
}

class _RelapseLogScreenState extends State<RelapseLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _causeController = TextEditingController();
  final _emotionsController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final entry = RelapseEntry(
        date: _selectedDate.toIso8601String(),
        cause: _causeController.text,
        emotions: _emotionsController.text,
        notes: _notesController.text,
      );

      await ProgressService.logRelapse(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Relapse logged. Stay strong.")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Log Relapse")),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: Form(
          key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              "It's okay to stumble. Logging this helps you understand your triggers.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 24),
            ListTile(
              title: Text("Date & Time"),
              subtitle: Text(_selectedDate.toString().split('.')[0]),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDate),
                  );
                  if (time != null) {
                    setState(() {
                      _selectedDate = DateTime(
                        date.year, date.month, date.day,
                        time.hour, time.minute,
                      );
                    });
                  }
                }
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _causeController,
              decoration: InputDecoration(
                labelText: "Cause / Trigger",
                border: OutlineInputBorder(),
                hintText: "What led to this?",
              ),
              validator: (v) => v?.isEmpty == true ? "Required" : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _emotionsController,
              decoration: InputDecoration(
                labelText: "Associated Emotions",
                border: OutlineInputBorder(),
                hintText: "How were you feeling?",
              ),
              validator: (v) => v?.isEmpty == true ? "Required" : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: "Notes (Optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Log Relapse"),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
