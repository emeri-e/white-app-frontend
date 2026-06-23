import 'package:flutter/material.dart';

class BlockBreakdownChart extends StatelessWidget {
  final Map<String, int> blockDistribution; // e.g. {'dns': 12, 'ai_screen': 8, 'camera_roll': 3, 'keyword': 5}

  const BlockBreakdownChart({super.key, required this.blockDistribution});

  Color _getSegmentColor(String key) {
    switch (key.toLowerCase()) {
      case 'dns':
        return Colors.blueAccent;
      case 'ai_screen':
      case 'ai_image':
      case 'ai_video':
        return Colors.purpleAccent;
      case 'camera_roll':
        return Colors.pinkAccent;
      case 'keyword':
        return Colors.orangeAccent;
      default:
        return Colors.tealAccent;
    }
  }

  String _getFriendlyLabel(String key) {
    switch (key.toLowerCase()) {
      case 'dns':
        return 'VPN / DNS Shield';
      case 'ai_screen':
      case 'ai_image':
      case 'ai_video':
        return 'AI Screen Guard';
      case 'camera_roll':
        return 'Gallery / Photos';
      case 'keyword':
        return 'Keyword Search';
      default:
        return 'Other Blocks';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = blockDistribution.values.fold<int>(0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'BLOCK DISTRIBUTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white38,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No block telemetry events logged.',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ),
            )
          else ...[
            // stacked bar segment
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: blockDistribution.entries.map((entry) {
                    final percentage = total > 0 ? entry.value / total : 0.0;
                    if (percentage == 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: (percentage * 100).round(),
                      child: Container(
                        color: _getSegmentColor(entry.key),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // detail lists with percentage labels
            Column(
              children: blockDistribution.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
                final color = _getSegmentColor(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getFriendlyLabel(entry.key),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} (${percentage.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
