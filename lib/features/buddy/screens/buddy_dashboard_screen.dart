import 'package:flutter/material.dart';
import 'package:whiteapp/features/buddy/models/buddy_pairing.dart';
import 'package:whiteapp/features/buddy/services/buddy_service.dart';
import 'package:whiteapp/features/buddy/widgets/streak_display_widget.dart';
import 'package:whiteapp/features/buddy/widgets/alert_timeline_widget.dart';
import 'package:whiteapp/features/buddy/widgets/block_breakdown_chart.dart';
import 'package:whiteapp/features/buddy/widgets/protection_status_card.dart';

class BuddyDashboardScreen extends StatefulWidget {
  const BuddyDashboardScreen({super.key});

  @override
  State<BuddyDashboardScreen> createState() => _BuddyDashboardScreenState();
}

class _BuddyDashboardScreenState extends State<BuddyDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  BuddyDashboardData? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await BuddyService.getBuddyDashboard();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleEmergencyLock() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1B4B), // Premium Indigo-dark
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50,
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
                  Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Trigger Emergency Lock?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This will immediately elevate all content shields on your partner\'s device to MAXIMUM security. Your partner will be locked out of configurations instantly and receive a security notification.',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'CONFIRM LOCKDOWN 🚨',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await BuddyService.triggerEmergencyLock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency lockdown activated successfully! 🚨'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _loadDashboard();
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lockdown failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleResetPin() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.pin_rounded, color: Colors.indigoAccent),
              SizedBox(width: 10),
              Text('Reset Security PIN', style: TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Current PIN',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New 4-6 Digit PIN',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New PIN',
                    labelStyle: TextStyle(color: Colors.white60),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
              onPressed: () {
                final curr = currentPinController.text.trim();
                final n = newPinController.text.trim();
                final c = confirmPinController.text.trim();

                if (curr.isEmpty || n.isEmpty || c.isEmpty) {
                  return;
                }
                if (n != c) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        await BuddyService.resetPIN(
          currentPinController.text.trim(),
          newPinController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security PIN successfully updated! ✓'),
            backgroundColor: Colors.greenAccent,
          ),
        );
        _loadDashboard();
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update PIN: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.indigoAccent),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Accountability Dashboard'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDashboard,
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData!;
    final pairing = data.pairing;

    // Build blockDistribution stats from alerts
    final blocks = {'dns': 0, 'ai_screen': 0, 'camera_roll': 0, 'keyword': 0};
    for (var alert in data.recentAlerts) {
      if (alert.alertType == 'block_event' || alert.alertType == 'ai_screen') {
        blocks['ai_screen'] = (blocks['ai_screen'] ?? 0) + 1;
      } else if (alert.alertType == 'keyword_search') {
        blocks['keyword'] = (blocks['keyword'] ?? 0) + 1;
      } else if (alert.alertType == 'camera_roll_flag') {
        blocks['camera_roll'] = (blocks['camera_roll'] ?? 0) + 1;
      } else if (alert.alertType == 'vpn_disabled') {
        blocks['dns'] = (blocks['dns'] ?? 0) + 1;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: Colors.indigoAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Glassmorphic App Bar
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                title: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.indigoAccent.withOpacity(0.2),
                      radius: 18,
                      child: Text(
                        (pairing.buddyName ?? pairing.userEmail).substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pairing.buddyName ?? 'Partner Shield',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            pairing.userEmail,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(24.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Streak Widget
                  StreakDisplayWidget(
                    currentStreak: data.currentStreak,
                    longestStreak: data.longestStreak,
                  ),
                  const SizedBox(height: 24),

                  // Diagnostics Device Status Telemetry
                  ProtectionStatusCard(
                    vpnActive: true, // Mock states or determined from recent sync/model
                    accessibilityActive: true,
                    cameraRollActive: true,
                    lastHeartbeat: DateTime.now().subtract(const Duration(minutes: 4)),
                  ),
                  const SizedBox(height: 24),

                  // Emergency lock & PIN action buttons row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ).button(
                          onPressed: _handleEmergencyLock,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'EMERGENCY LOCK',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.04),
                          side: const BorderSide(color: Colors.white10),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ).button(
                          onPressed: _handleResetPin,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.password_rounded, color: Colors.indigoAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'RESET PIN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weekly breakdown chart
                  BlockBreakdownChart(blockDistribution: blocks),
                  const SizedBox(height: 24),

                  // Weekly progress report cards header
                  const Text(
                    'WEEKLY SUMMARY CARDS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white38,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildWeeklyReportCard('CURRENT WEEK', '12 Blocks matched', Colors.indigoAccent),
                        const SizedBox(width: 12),
                        _buildWeeklyReportCard('PAST WEEK (MAY 14)', '0 Alerts logged ✓', Colors.greenAccent),
                        const SizedBox(width: 12),
                        _buildWeeklyReportCard('PAST WEEK (MAY 07)', '3 Blocks matches', Colors.indigoAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Event timelines
                  const Text(
                    'SECURITY LOG TIMELINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white38,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AlertTimelineWidget(alerts: data.recentAlerts),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyReportCard(String title, String summary, Color accent) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to adapt custom styles to ElevatedButton easily
extension _ElevatedButtonExtension on ButtonStyle {
  Widget button({required VoidCallback onPressed, required Widget child}) {
    return ElevatedButton(
      style: this,
      onPressed: onPressed,
      child: child,
    );
  }
}
