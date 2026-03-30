import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import 'dart:convert';
import '../../../core/constants/env.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _dailyReminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _challengeAlerts = true;
  bool _levelAlerts = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPreferences();
  }

  Future<void> _fetchPreferences() async {
    try {
      final response = await ApiService.get('${Env.apiBase}/notifications/preferences/');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _dailyReminderEnabled = data['daily_reminder_enabled'] ?? true;
          _challengeAlerts = data['challenge_alerts'] ?? true;
          _levelAlerts = data['level_alerts'] ?? true;
          if (data['reminder_time'] != null) {
            final parts = data['reminder_time'].toString().split(':');
            _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch preferences: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final formattedTime = '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}:00';
      await ApiService.put('${Env.apiBase}/notifications/preferences/', {
        'daily_reminder_enabled': _dailyReminderEnabled,
        'reminder_time': formattedTime,
        'challenge_alerts': _challengeAlerts,
        'level_alerts': _levelAlerts,
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences Saved', style: TextStyle(color: Colors.white))));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving preferences')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            activeColor: Theme.of(context).primaryColor,
            title: const Text('Daily Reminders'),
            subtitle: const Text('Get nudged about your recovery momentum'),
            value: _dailyReminderEnabled,
            onChanged: (val) {
              setState(() => _dailyReminderEnabled = val);
              _savePreferences();
            },
          ),
          if (_dailyReminderEnabled)
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Reminder Time'),
              trailing: Text(_reminderTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                final newTime = await showTimePicker(context: context, initialTime: _reminderTime);
                if (newTime != null) {
                  setState(() => _reminderTime = newTime);
                  _savePreferences();
                }
              },
            ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Challenge Alerts'),
            subtitle: const Text('Notices for time-based recovery badges'),
            value: _challengeAlerts,
            onChanged: (val) {
              setState(() => _challengeAlerts = val);
              _savePreferences();
            },
          ),
          SwitchListTile(
            title: const Text('Level Up Alerts'),
            subtitle: const Text('Notices when new recovery tiers unlock'),
            value: _levelAlerts,
            onChanged: (val) {
              setState(() => _levelAlerts = val);
              _savePreferences();
            },
          ),
        ],
      ),
    );
  }
}
