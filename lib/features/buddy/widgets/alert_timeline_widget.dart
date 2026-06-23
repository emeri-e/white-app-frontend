import 'package:flutter/material.dart';
import 'package:whiteapp/features/buddy/models/buddy_pairing.dart';

class AlertTimelineWidget extends StatefulWidget {
  final List<BuddyAlert> alerts;

  const AlertTimelineWidget({super.key, required this.alerts});

  @override
  State<AlertTimelineWidget> createState() => _AlertTimelineWidgetState();
}

class _AlertTimelineWidgetState extends State<AlertTimelineWidget> {
  String _selectedFilter = 'All';
  final Map<int, bool> _expandedState = {};

  List<BuddyAlert> get _filteredAlerts {
    if (_selectedFilter == 'All') return widget.alerts;
    if (_selectedFilter == 'Blocks') {
      return widget.alerts.where((a) => a.alertType == 'block_event' || a.alertType == 'keyword_search' || a.alertType == 'camera_roll_flag').toList();
    }
    if (_selectedFilter == 'System') {
      return widget.alerts.where((a) => a.alertType == 'vpn_disabled' || a.alertType == 'accessibility_revoked' || a.alertType == 'app_uninstall').toList();
    }
    return widget.alerts;
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.amberAccent;
      case 'low':
      default:
        return Colors.greenAccent;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'vpn_disabled':
      case 'accessibility_revoked':
        return Icons.vpn_lock_rounded;
      case 'app_uninstall':
        return Icons.delete_forever_rounded;
      case 'camera_roll_flag':
        return Icons.photo_library_rounded;
      case 'keyword_search':
        return Icons.search_off_rounded;
      case 'block_event':
      default:
        return Icons.block_flipped;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAlerts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter chips row
        Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 8),
            _buildFilterChip('Blocks'),
            const SizedBox(width: 8),
            _buildFilterChip('System'),
          ],
        ),
        const SizedBox(height: 16),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 40),
                SizedBox(height: 12),
                Text(
                  'No alerts registered',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Everything is clean and running perfectly.',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final alert = list[index];
              final isExpanded = _expandedState[alert.id] ?? false;
              final color = _getSeverityColor(alert.severity);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline track bar and node indicators
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 3),
                          ),
                        ),
                        if (index < list.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.white12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Alert description card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _expandedState[alert.id] = !isExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(isExpanded ? 0.08 : 0.04),
                              border: Border.all(color: isExpanded ? color.withOpacity(0.3) : Colors.white10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getAlertIcon(alert.alertType),
                                      color: color,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        alert.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(alert.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  alert.body,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                ),
                                if (isExpanded && alert.data != null && alert.data!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: alert.data!.entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 4.0),
                                          child: Row(
                                            children: [
                                              Text(
                                                '${entry.key}: ',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white38,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  '${entry.value}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final active = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = label);
        }
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.25),
      backgroundColor: Colors.white.withOpacity(0.04),
      side: BorderSide(
        color: active ? Theme.of(context).primaryColor : Colors.white10,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: active ? Colors.white : Colors.white60,
      ),
    );
  }
}
