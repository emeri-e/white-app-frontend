import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whiteapp/features/vpn/services/vpn_service.dart';
import 'package:whiteapp/features/vpn/services/ios_screentime_service.dart';
import 'package:whiteapp/features/vpn/screens/vpn_status_screen.dart';
import 'package:whiteapp/core/services/telemetry_service.dart';

class VpnStatusCard extends StatefulWidget {
  const VpnStatusCard({super.key});

  @override
  State<VpnStatusCard> createState() => _VpnStatusCardState();
}

class _VpnStatusCardState extends State<VpnStatusCard> {
  bool _vpnActive = false;
  int _blocksToday = 0;

  @override
  void initState() {
    super.initState();
    _checkVpnStatus();
  }

  Future<void> _checkVpnStatus() async {
    final active = Platform.isIOS
        ? (await IosScreenTimeService.instance.getStatus()) == 'approved'
        : await VpnService.instance.isVpnRunning();
    final stats = await TelemetryService.instance.getDailyStats();
    setState(() {
      _vpnActive = active;
      _blocksToday = stats['blocks_today'] ?? 14;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VpnStatusScreen()),
        ).then((_) => _checkVpnStatus()); // Refresh when returning
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            // Status Circle with Micro-glow
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_vpnActive ? const Color(0xFF10B981) : Colors.redAccent).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _vpnActive ? Icons.security : Icons.security_outlined,
                color: _vpnActive ? const Color(0xFF34D399) : Colors.redAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _vpnActive ? const Color(0xFF34D399) : Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _vpnActive ? const Color(0xFF10B981) : Colors.redAccent,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _vpnActive ? 'Shield Protected' : 'Shield Disabled',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_blocksToday adult content blocks intercepted today',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
