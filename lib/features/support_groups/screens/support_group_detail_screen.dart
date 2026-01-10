import 'package:flutter/material.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:whiteapp/features/support_groups/screens/live_session_screen.dart';

class SupportGroupDetailScreen extends StatefulWidget {
  final int groupId;

  const SupportGroupDetailScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<SupportGroupDetailScreen> createState() => _SupportGroupDetailScreenState();
}

class _SupportGroupDetailScreenState extends State<SupportGroupDetailScreen> {
  SupportGroup? _group;
  bool _isLoading = true;
  String? _error;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final group = await SupportGroupService.getGroupDetail(widget.groupId);
      setState(() {
        _group = group;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    setState(() => _isJoining = true);
    try {
      // For paid groups, we'd need to handle payment flow here
      await SupportGroupService.joinGroup(widget.groupId);
      await _loadGroup(); // Refresh to update isMember status
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined group successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    } finally {
      setState(() => _isJoining = false);
    }
  }

  void _enterSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveSessionScreen(group: _group!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    final group = _group!;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Text(
              group.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              group.programName,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Therapist Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: group.therapist['avatar_url'] != null
                      ? NetworkImage(group.therapist['avatar_url'])
                      : null,
                  child: group.therapist['avatar_url'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.therapist['name'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (group.therapist['bio'] != null)
                      Text(
                        group.therapist['bio'],
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Details Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3,
              children: [
                _buildDetailItem(Icons.calendar_today, '${group.sessionCount} Sessions'),
                _buildDetailItem(Icons.access_time, '${group.weeklyStartTime}'),
                _buildDetailItem(Icons.attach_money, group.formattedPrice),
                _buildDetailItem(Icons.people, '${group.availableSeats} seats left'),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            const Text(
              'About this Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(group.description),
            const SizedBox(height: 16),
            if (group.goals.isNotEmpty) ...[
              const Text(
                'Goals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(group.goals),
            ],
            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: group.isMember
                  ? ElevatedButton.icon(
                      onPressed: _enterSession,
                      icon: const Icon(Icons.video_call),
                      label: const Text('Enter Live Session'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _isJoining || group.availableSeats == 0 ? null : _joinGroup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isJoining
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(group.availableSeats == 0 ? 'Group Full' : 'Join Group'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
