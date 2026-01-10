import 'package:flutter/material.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:whiteapp/features/support_groups/screens/support_group_detail_screen.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class SupportGroupListScreen extends StatefulWidget {
  const SupportGroupListScreen({Key? key}) : super(key: key);

  @override
  State<SupportGroupListScreen> createState() => _SupportGroupListScreenState();
}

class _SupportGroupListScreenState extends State<SupportGroupListScreen> {
  List<SupportGroup> _groups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await SupportGroupService.getGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Therapy'),
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _groups.isEmpty
                  ? const Center(child: Text('No support groups available for your programs.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SupportGroupDetailScreen(groupId: group.id),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    group.programName,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage: group.therapist['avatar_url'] != null
                                            ? NetworkImage(group.therapist['avatar_url'])
                                            : null,
                                        child: group.therapist['avatar_url'] == null
                                            ? const Icon(Icons.person, size: 16)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('Hosted by ${group.therapist['name']}'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        group.formattedPrice,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        '${group.availableSeats} seats left',
                                        style: TextStyle(
                                          color: group.availableSeats > 0 ? Colors.blue : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}
