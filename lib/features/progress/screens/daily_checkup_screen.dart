import 'package:flutter/material.dart';
import 'package:whiteapp/features/progress/models/program_tracker_entry.dart';
import 'package:whiteapp/features/progress/screens/mood_checkin_screen.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';

class DailyCheckupScreen extends StatefulWidget {
  const DailyCheckupScreen({Key? key}) : super(key: key);

  @override
  _DailyCheckupScreenState createState() => _DailyCheckupScreenState();
}

class _DailyCheckupScreenState extends State<DailyCheckupScreen> {
  bool _isLoading = true;
  bool _moodCheckinNeeded = false;
  List<ProgramTrackerConfig> _trackerConfigs = [];
  final Map<int, int> _trackerValues = {};
  final Map<int, TextEditingController> _trackerNotes = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ProgressService.getDailyCheckup();
      setState(() {
        _moodCheckinNeeded = data['mood_checkin_needed'] ?? false;
        final List<dynamic> trackers = data['program_trackers'] ?? [];
        _trackerConfigs = trackers.map((e) => ProgramTrackerConfig.fromJson(e)).toList();
        
        for (var config in _trackerConfigs) {
          _trackerValues[config.id] = config.minValue; // Default to min
          _trackerNotes[config.id] = TextEditingController();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading checkup: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitTracker(ProgramTrackerConfig config) async {
    try {
      final entry = ProgramTrackerEntry(
        configId: config.id,
        date: DateTime.now().toIso8601String().split('T')[0],
        value: _trackerValues[config.id]!,
        note: _trackerNotes[config.id]!.text,
      );
      
      await ProgressService.logTrackerEntry(entry);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logged ${config.label}")),
      );
      
      // Remove from list or mark as done (for now just reload or disable)
      // Ideally we'd track which ones are done today in the backend response
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Daily Checkup")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Daily Checkup")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_moodCheckinNeeded) ...[
            Card(
              child: ListTile(
                leading: Icon(Icons.mood, color: Colors.blue),
                title: Text("Mood Check-in"),
                subtitle: Text("How are you feeling today?"),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MoodCheckinScreen()),
                  );
                  if (result == true) {
                    setState(() {
                      _moodCheckinNeeded = false; // Optimistic update
                    });
                  }
                },
              ),
            ),
            SizedBox(height: 16),
          ],
          if (_trackerConfigs.isEmpty && !_moodCheckinNeeded)
            Center(child: Text("All caught up for today!")),
            
          ..._trackerConfigs.map((config) {
            return Card(
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.label, style: Theme.of(context).textTheme.titleMedium),
                    if (config.helpText != null)
                      Text(config.helpText!, style: Theme.of(context).textTheme.bodySmall),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(config.minValue.toString()),
                        Expanded(
                          child: Slider(
                            value: _trackerValues[config.id]!.toDouble(),
                            min: config.minValue.toDouble(),
                            max: config.maxValue.toDouble(),
                            divisions: (config.maxValue - config.minValue) > 0 
                                ? (config.maxValue - config.minValue) 
                                : 1,
                            label: _trackerValues[config.id].toString(),
                            onChanged: (val) {
                              setState(() {
                                _trackerValues[config.id] = val.toInt();
                              });
                            },
                          ),
                        ),
                        Text(config.maxValue.toString()),
                      ],
                    ),
                    Text("Current Value: ${_trackerValues[config.id]}"),
                    SizedBox(height: 8),
                    TextField(
                      controller: _trackerNotes[config.id],
                      decoration: InputDecoration(
                        labelText: "Note (Optional)",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _submitTracker(config),
                        child: Text("Save"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
