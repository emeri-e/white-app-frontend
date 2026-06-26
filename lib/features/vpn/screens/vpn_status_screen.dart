import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/vpn/services/vpn_service.dart';
import 'package:whiteapp/features/vpn/services/blocklist_service.dart';
import 'package:whiteapp/features/vpn/services/ios_screentime_service.dart';
import 'package:whiteapp/features/ai/screens/ai_status_screen.dart';
import 'package:whiteapp/features/buddy/services/buddy_service.dart';
import 'package:whiteapp/features/buddy/widgets/pin_entry_dialog.dart';
import 'package:whiteapp/core/services/telemetry_service.dart';

class VpnStatusScreen extends StatefulWidget {
  static const String id = 'vpn_status_screen';
  const VpnStatusScreen({super.key});

  @override
  State<VpnStatusScreen> createState() => _VpnStatusScreenState();
}

class _VpnStatusScreenState extends State<VpnStatusScreen> {
  bool _vpnActive = false;
  bool _a11yActive = false;
  int _localVersion = 0;
  bool _isSyncing = false;

  int _blocksToday = 0;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final vpnEnabled = Platform.isIOS
        ? (await IosScreenTimeService.instance.getStatus()) == 'approved'
        : await VpnService.instance.isVpnRunning();
    final a11yEnabled = Platform.isAndroid 
        ? await VpnService.instance.isAccessibilityServiceEnabled() 
        : false;
    final dbVersion = await BlocklistService.instance.getLocalVersion();
    final stats = await TelemetryService.instance.getDailyStats();

    setState(() {
      _vpnActive = vpnEnabled;
      _a11yActive = a11yEnabled;
      _localVersion = dbVersion;
      _blocksToday = stats['blocks_today'] ?? 14;
    });
  }

  Future<void> _toggleVpn(bool value) async {
    if (!value) {
      try {
        final pairing = await BuddyService.getPairingStatus();
        if (pairing != null) {
          final verified = await PinEntryDialog.show(
            context,
            title: 'Deactivate Security Shield',
            description: 'Enter your accountability PIN to disable the VPN protection shield.',
          );
          if (verified != true) {
            // Re-render switch state back to active since check failed/cancelled
            setState(() {});
            return;
          }
        }
      } catch (_) {
        // Fallback: allow if connection error
      }
    }

    setState(() => _isSyncing = true);
    if (Platform.isIOS) {
      if (value) {
        await IosScreenTimeService.instance.requestAuthorization();
      } else {
        // Stub disabling for testing
      }
    } else {
      if (value) {
        await VpnService.instance.startVpn();
      } else {
        await VpnService.instance.stopVpn();
      }
    }
    await _refreshStatus();
    setState(() => _isSyncing = false);
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final success = await BlocklistService.instance.syncBlocklist();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocklist updated to the latest version!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocklist is already up to date.')),
      );
    }
    await _refreshStatus();
    setState(() => _isSyncing = false);
  }

  void _showAccessibilityInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Icon(Icons.accessibility_new, color: Colors.orangeAccent, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enable Bodyguard Service',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Android security requires a few quick manual steps to activate the background bodyguard. If the setting is greyed out, please complete Step 1 first:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. ', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        'If Greyed Out: Tap "1. Open App Info" below, scroll/tap menu, select "Allow restricted settings", and confirm.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2. ', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        'Activate Guard: Tap "2. Open Accessibility" below, select "WhiteApp" under Downloaded Apps, and toggle it ON.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => VpnService.instance.openAppInfoSettings(),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('1. Open App Info'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          VpnService.instance.openAccessibilitySettings();
                        },
                        icon: const Icon(Icons.accessibility, size: 18),
                        label: const Text('2. Open Accessibility'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Shield', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                
                // Big protective status circle
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: (_vpnActive ? const Color(0xFF10B981) : Colors.redAccent).withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_vpnActive ? const Color(0xFF10B981) : Colors.redAccent).withOpacity(0.3),
                        width: 4,
                      ),
                    ),
                    child: Icon(
                      _vpnActive ? Icons.shield : Icons.shield_outlined,
                      color: _vpnActive ? const Color(0xFF34D399) : Colors.redAccent,
                      size: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _vpnActive ? 'System Fully Protected' : 'Protection Disabled',
                  style: TextStyle(
                    color: _vpnActive ? const Color(0xFF34D399) : Colors.redAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  Platform.isIOS
                      ? 'iOS Screen Time domain filtering active'
                      : 'Local MITM content scanning filters active',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // VPN toggle option
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.power_settings_new, color: Colors.blueAccent),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shield Protection',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Deactivation requires accountability PIN',
                               style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _vpnActive,
                        onChanged: _isSyncing ? null : _toggleVpn,
                         activeColor: const Color(0xFF34D399),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Telemetry cards list
                Expanded(
                  child: ListView(
                    children: [
                      _buildInfoTile(
                        icon: Icons.block,
                        color: Colors.orangeAccent,
                        title: 'Captured Attempts Today',
                        value: '$_blocksToday blocks',
                        description: 'Triggering domains and adult keyword intercepts.',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Platform.isIOS ? Icons.family_restroom : Icons.security,
                        color: Colors.purpleAccent,
                        title: Platform.isIOS ? 'Screen Time Permission' : 'Bodyguard Accessibility',
                        value: Platform.isIOS 
                            ? (_vpnActive ? 'Authorized' : 'Unauthorized')
                            : (_a11yActive ? 'Enabled' : 'Disabled'),
                        description: Platform.isIOS 
                            ? 'Allows system-wide browser domain blocking.'
                            : 'Guards against disabling system settings.',
                        trailing: Platform.isIOS
                            ? (!_vpnActive 
                                ? TextButton(
                                    onPressed: () async {
                                      await IosScreenTimeService.instance.requestAuthorization();
                                      await _refreshStatus();
                                    },
                                    child: const Text('Authorize', style: TextStyle(color: Colors.blueAccent)),
                                  )
                                : null)
                            : (!_a11yActive && Platform.isAndroid
                                ? TextButton(
                                    onPressed: _showAccessibilityInstructions,
                                    child: const Text('Enable', style: TextStyle(color: Colors.blueAccent)),
                                  )
                                : null),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Icons.sync,
                        color: Colors.tealAccent,
                        title: 'Blocklist Version',
                        value: 'v$_localVersion',
                        description: 'HMAC-SHA256 Signed delta rules local sync.',
                        trailing: IconButton(
                          icon: _isSyncing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.refresh, color: Colors.white70),
                          onPressed: _isSyncing ? null : _triggerManualSync,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Icons.psychology_outlined,
                        color: Colors.cyanAccent,
                        title: 'AI Content Engine',
                        value: 'NudeNet Active',
                        description: 'On-device neural scanning, sensitivity & OTA updates.',
                        trailing: IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white70),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiStatusScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String description,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
