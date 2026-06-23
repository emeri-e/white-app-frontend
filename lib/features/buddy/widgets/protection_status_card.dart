import 'package:flutter/material.dart';

class ProtectionStatusCard extends StatelessWidget {
  final bool vpnActive;
  final bool accessibilityActive;
  final bool cameraRollActive;
  final DateTime? lastHeartbeat;

  const ProtectionStatusCard({
    super.key,
    required this.vpnActive,
    required this.accessibilityActive,
    required this.cameraRollActive,
    this.lastHeartbeat,
  });

  String _formatHeartbeat(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  bool _isStale() {
    if (lastHeartbeat == null) return true;
    final diff = DateTime.now().difference(lastHeartbeat!);
    return diff.inHours >= 1;
  }

  @override
  Widget build(BuildContext context) {
    final stale = _isStale();
    final anyLayerOff = !vpnActive || !accessibilityActive || !cameraRollActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (anyLayerOff || stale)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VULNERABILITY DETECTED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.redAccent,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stale
                            ? "Device hasn't synced heartbeat in over an hour."
                            : 'One or more local protection layers are currently inactive.',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SHIELD PROTECTIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white38,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Sync: ${_formatHeartbeat(lastHeartbeat)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLayerRow(
                context,
                'VPN Tunneling Filter',
                'Secures outgoing network connections and intercepts adult domains',
                vpnActive,
              ),
              const Divider(color: Colors.white10, height: 24),
              _buildLayerRow(
                context,
                'Screen Accessibility Guard',
                'Intercepts neural scanner and blocks blacklisted keyword searches',
                accessibilityActive,
              ),
              const Divider(color: Colors.white10, height: 24),
              _buildLayerRow(
                context,
                'Gallery roll scanner',
                'Monitors local media library changes to flag explicit content',
                cameraRollActive,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayerRow(BuildContext context, String title, String desc, bool active) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.shield_rounded : Icons.shield_outlined,
            color: active ? Colors.greenAccent : Colors.redAccent,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          active ? 'ACTIVE' : 'OFF',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: active ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
      ],
    );
  }
}
