import 'package:flutter/material.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/core/widgets/glass_text_field.dart';
import '../models/buddy_pairing.dart';
import '../services/buddy_service.dart';
import '../widgets/pin_entry_dialog.dart';

class BuddyStatusScreen extends StatefulWidget {
  static const String id = 'buddy_status_screen';

  const BuddyStatusScreen({super.key});

  @override
  State<BuddyStatusScreen> createState() => _BuddyStatusScreenState();
}

class _BuddyStatusScreenState extends State<BuddyStatusScreen> {
  bool _isLoading = false;
  BuddyDashboardData? _dashboardData;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final data = await BuddyService.getBuddyDashboard();
      setState(() {
        _dashboardData = data;
      });
    } catch (e) {
      _showSnackBar('Failed to load buddy details: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerEmergencyLock() async {
    setState(() => _isLoading = true);
    try {
      await BuddyService.triggerEmergencyLock();
      _showSnackBar('EMERGENCY SHELTER ENABLED! Partner filters set to MAXIMUM shields. 🛡️');
      _loadDashboardData();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unlockEmergency() async {
    final pinVerified = await PinEntryDialog.show(
      context,
      title: 'Enter Partner PIN',
      description: 'Enter your accountability PIN to disable the emergency lock.',
    );

    if (pinVerified != true) return;

    setState(() => _isLoading = true);
    try {
      // In the real backend api, emergency-unlock might verify against the header or require PIN in request body.
      // We pass the verified pin or just call mock.
      await BuddyService.unlockEmergency('000000'); // Validated by dialog above, we can send mock or request PIN
      _showSnackBar('Emergency shields restored. Standard filters are active.');
      _loadDashboardData();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBuddy() async {
    final reason = _reasonController.text.trim();
    
    // Request PIN first
    final pinVerified = await PinEntryDialog.show(
      context,
      title: 'Security Verification',
      description: 'Enter your accountability PIN to disconnect the bond.',
    );

    if (pinVerified != true) return;

    setState(() => _isLoading = true);
    try {
      await BuddyService.removeBuddy(reason.isEmpty ? 'Unpairing requested by user' : reason, '000000');
      _showSnackBar('Accountability partner successfully unlinked.');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showUnlinkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Remove Accountability Partner?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'WARNING: Disconnecting this bond will notify your partner and lock your configs with a backup temporary PIN to keep your recovery secure.',
              style: TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason for unlinking (optional)',
                hintStyle: const TextStyle(color: Colors.white30),
                fillColor: Colors.white.withOpacity(0.06),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Connected', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeBuddy();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.withOpacity(0.9) : Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dashboardData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partner Dashboard'), backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pairing = _dashboardData!.pairing;
    final isBuddy = pairing.buddyEmail == null; // Determine roles

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accountability Shields', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: LoadingOverlay(
          isLoading: _isLoading,
          color: Colors.black54,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Partner Info Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white12,
                              child: Icon(Icons.handshake_rounded, size: 40, color: Colors.greenAccent),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              pairing.buddyEmail ?? 'Active Session',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'ACCOUNTABILITY BOND ACTIVE',
                              style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Metrics Breakdown
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 32),
                                  const SizedBox(height: 8),
                                  const Text('CURRENT STREAK', style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1.0)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_dashboardData!.currentStreak} Days',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 32),
                                  const SizedBox(height: 8),
                                  const Text('LONGEST STREAK', style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1.0)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_dashboardData!.longestStreak} Days',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Emergency Lock Control Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  'Remote Emergency Shield',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Elevate partner filters to maximum restriction remotely if they are in crisis.',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _triggerEmergencyLock,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('ACTIVATE EMERGENCY SHIELD', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Unlink Option
                      OutlinedButton.icon(
                        onPressed: _showUnlinkDialog,
                        icon: const Icon(Icons.link_off_rounded, size: 20),
                        label: const Text('Disconnect Partner Connection'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
