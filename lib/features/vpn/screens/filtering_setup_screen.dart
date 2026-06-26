import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/home/screens/home_screen.dart';
import 'package:whiteapp/features/vpn/services/vpn_service.dart';
import 'package:whiteapp/features/vpn/services/blocklist_service.dart';
import 'package:whiteapp/features/vpn/services/heartbeat_service.dart';
import 'package:whiteapp/features/vpn/services/block_reporter_service.dart';
import 'package:whiteapp/features/vpn/services/ios_screentime_service.dart';
import 'package:whiteapp/features/buddy/services/buddy_service.dart';
import 'package:whiteapp/features/buddy/widgets/pin_entry_dialog.dart';

class FilteringSetupScreen extends StatefulWidget {
  static const String id = 'filtering_setup_screen';
  const FilteringSetupScreen({super.key});

  @override
  State<FilteringSetupScreen> createState() => _FilteringSetupScreenState();
}

class _FilteringSetupScreenState extends State<FilteringSetupScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;

  // Active status checks
  bool _certInstalled = false;
  bool _vpnActive = false;
  bool _a11yActive = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPinGate());
  }

  Future<void> _checkPinGate() async {
    try {
      final pairing = await BuddyService.getPairingStatus();
      if (pairing != null) {
        final verified = await PinEntryDialog.show(
          context,
          title: 'Shield Configuration Lock',
          description: 'Enter your accountability PIN to access or reconfigure protection settings.',
        );
        if (verified != true) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (_) {
      // Fallback: allow on error
    }
  }

  Timer? _certCheckTimer;

  @override
  void dispose() {
    _certCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialPermissions() async {
    if (Platform.isIOS) {
      final isAuthorized = (await IosScreenTimeService.instance.getStatus()) == 'approved';
      setState(() {
        _vpnActive = isAuthorized;
      });
      return;
    }

    final vpnEnabled = await VpnService.instance.isVpnRunning();
    final certInstalled = await VpnService.instance.isCertificateInstalled();
    final a11yEnabled = Platform.isAndroid 
        ? await VpnService.instance.isAccessibilityServiceEnabled() 
        : false;

    setState(() {
      _vpnActive = vpnEnabled;
      _certInstalled = certInstalled;
      _a11yActive = a11yEnabled;
    });
  }

  Future<void> _installRootCertificate() async {
    final manual = await VpnService.instance.requiresManualInstallation();
    if (!manual) {
      // Android 10 and below: automatic install
      setState(() => _isProcessing = true);
      final success = await VpnService.instance.installCertificate();
      if (success) {
        _startCertVerificationTimer(autoAdvance: true);
      } else {
        setState(() => _isProcessing = false);
      }
    } else {
      // Android 11+: manual installation required
      _showManualInstallInstructions();
    }
  }

  void _startCertVerificationTimer({required bool autoAdvance}) {
    _certCheckTimer?.cancel();
    _certCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final installed = await VpnService.instance.isCertificateInstalled();
      if (installed) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _certInstalled = true;
            _isProcessing = false;
          });
          if (!autoAdvance) {
            // Close instructions bottom sheet if it's still open
            Navigator.of(context).pop(); 
          }
          _nextStep();
        }
      }
    });
  }

  void _showManualInstallInstructions() {
    _startCertVerificationTimer(autoAdvance: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E), // Premium dark theme background
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
                    Icon(Icons.verified_user, color: Colors.purpleAccent, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Install Trusted CA Certificate',
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
                  'Modern Android security systems (Android 11+) require CA certificates to be trusted manually via system settings. Please follow these steps:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInstructionStep(
                  stepNum: '1',
                  title: 'Save Certificate File',
                  description: 'Tap "Export & Open Settings" below. This exports the "whiteapp-ca.crt" file to your Downloads folder.',
                ),
                _buildInstructionStep(
                  stepNum: '2',
                  title: 'Navigate to Security Settings',
                  description: 'In the settings window that opens, scroll to and select "Encryption & credentials" (or "More security settings").',
                ),
                _buildInstructionStep(
                  stepNum: '3',
                  title: 'Choose CA Certificate',
                  description: 'Select "Install a certificate" -> "CA certificate". Select "Install anyway" if a security warning appears.',
                ),
                _buildInstructionStep(
                  stepNum: '4',
                  title: 'Select the Saved File',
                  description: 'Go to your Downloads folder and pick the "whiteapp-ca.crt" file. Authorize using your device PIN.',
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    // Export and redirect to Settings
                    await VpnService.instance.installCertificate();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Export & Open Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
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
    ).then((_) {
      // Cancel verification check if bottom sheet is manually dismissed
      _certCheckTimer?.cancel();
    });
  }

  Widget _buildInstructionStep({
    required String stepNum,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.purpleAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enableVpn() async {
    setState(() => _isProcessing = true);
    final success = await VpnService.instance.startVpn();
    setState(() {
      _vpnActive = success;
      _isProcessing = false;
    });
    if (success) {
      _nextStep();
    }
  }

  void _showAccessibilityInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E), // Premium dark theme background
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
                _buildInstructionStep(
                  stepNum: '1',
                  title: 'If Greyed Out: Unlock Restricted Settings',
                  description: 'Tap "1. Open App Info" below. Scroll to the bottom (or tap the 3-dots at the top right) and select "Allow restricted settings". Confirm with your PIN.',
                ),
                _buildInstructionStep(
                  stepNum: '2',
                  title: 'Activate the Guard Service',
                  description: 'Tap "2. Open Accessibility" below. Tap "Downloaded Apps" (or "Installed Services"), select "WhiteApp", and toggle "Use WhiteApp" to ON.',
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
                          _enableAccessibilityDirect();
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

  Future<void> _enableAccessibility() async {
    if (!Platform.isAndroid) {
      _nextStep();
      return;
    }
    _showAccessibilityInstructions();
  }

  Future<void> _enableAccessibilityDirect() async {
    setState(() => _isProcessing = true);
    await VpnService.instance.openAccessibilitySettings();

    // Spawn periodic check to see if permission has been granted
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final enabled = await VpnService.instance.isAccessibilityServiceEnabled();
      if (enabled) {
        timer.cancel();
        setState(() {
          _a11yActive = true;
          _isProcessing = false;
        });
        _nextStep();
      }
    });
  }

  void _nextStep() {
    final maxStep = Platform.isIOS ? 2 : 4;
    if (_currentStep < maxStep) {
      setState(() => _currentStep++);
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isProcessing = true);

    // Initial database pull and configurations
    await BlocklistService.instance.forceFullSync();

    // Save completion flag in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('filtering_setup_completed', true);
    
    // Start periodic background services
    HeartbeatService.instance.start();
    BlockReporterService.instance.start();

    setState(() => _isProcessing = false);
    
    // Redirect cleanly to HomeScreen
    Navigator.pushReplacementNamed(context, HomeScreen.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Heading
                Text(
                  'Content Shield Setup',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  Platform.isIOS
                      ? 'Step ${_currentStep + 1} of 3'
                      : 'Step ${_currentStep + 1} of 5',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Main setup contents based on Page state
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildCurrentStepWidget(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Button controls
                if (_isProcessing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _handleStepAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          _getStepButtonText(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_currentStep == 3 && !_a11yActive) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            _nextStep();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                          ),
                          child: const Text(
                            'Skip this step (If setting is locked/unsupported)',
                            style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    if (Platform.isIOS) {
      switch (_currentStep) {
        case 0:
          return _buildCardWrapper(
            icon: Icons.shield_outlined,
            color: Colors.blueAccent,
            title: 'iOS Secure Filtering',
            description:
                'WhiteApp uses Apple\'s native Screen Time and FamilyControls APIs to perform secure, system-wide domain blocking. Your privacy is fully preserved, and no personal web data ever leaves your device.',
          );
        case 1:
          return _buildCardWrapper(
            icon: Icons.family_restroom_outlined,
            color: Colors.purpleAccent,
            title: 'Authorize Screen Time',
            description:
                'To enable content filtering, WhiteApp requires authorization via the Apple Screen Time system. Tap below to authorize.',
            statusWidget: _vpnActive ? _buildSuccessBadge() : null,
          );
        case 2:
        default:
          return _buildCardWrapper(
            icon: Icons.check_circle_outline,
            color: const Color(0xFF34D399),
            title: 'Shield fully active!',
            description:
                'Awesome! Your Screen Time blocking layer is fully configured. Your device is permanently shielded from explicit and triggering materials.',
          );
      }
    }

    switch (_currentStep) {
      case 0:
        return _buildCardWrapper(
          icon: Icons.shield_outlined,
          color: Colors.blueAccent,
          title: 'Secure Local Filtering',
          description:
              'WhiteApp uses a secure, local man-in-the-middle proxy to intercept, decrypt, and dynamically inspect images and video on your device before they appear on screen. Your traffic never leaves your device.',
        );
      case 1:
        return _buildCardWrapper(
          icon: Icons.verified_user_outlined,
          color: Colors.purpleAccent,
          title: 'Trust SSL Certificate',
          description:
              'To decrypt and inspect secure HTTPS web requests locally, we must install a local root certificate. This allows your device to trust the self-generated filtering proxy.',
          statusWidget: _certInstalled ? _buildSuccessBadge() : null,
        );
      case 2:
        return _buildCardWrapper(
          icon: Icons.vpn_lock_outlined,
          color: Colors.tealAccent,
          title: 'Initialize VPN tunnel',
          description:
              'A local loopback VPN is used to route internet data packages to the inspector proxy on your device. Click enable and allow the standard Android prompt.',
          statusWidget: _vpnActive ? _buildSuccessBadge() : null,
        );
      case 3:
        return _buildCardWrapper(
          icon: Icons.security_outlined,
          color: Colors.orangeAccent,
          title: 'Bodyguard Activation',
          description:
              'To prevent VPN bypass and protect the app from being disabled, we use an Accessibility Service. Please tap below, select "Downloaded Apps" (or "Installed Services"), select "WhiteApp", and toggle "Use WhiteApp" to ON.',
          statusWidget: _a11yActive ? _buildSuccessBadge() : null,
        );
      case 4:
      default:
        return _buildCardWrapper(
          icon: Icons.check_circle_outline,
          color: const Color(0xFF34D399),
          title: 'Shield fully active!',
          description:
              'Awesome! Your local content blocking layer is fully configured. Your device is permanently shielded from explicit and triggering materials.',
        );
    }
  }

  Widget _buildCardWrapper({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    Widget? statusWidget,
  }) {
    return Container(
      key: ValueKey(title),
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 56),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (statusWidget != null) ...[
            const SizedBox(height: 20),
            statusWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.2),
        border: Border.all(color: const Color(0xFF10B981)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: Color(0xFF34D399), size: 16),
          SizedBox(width: 8),
          Text(
            'ACTIVE',
            style: TextStyle(
              color: Color(0xFF34D399),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepButtonText() {
    if (Platform.isIOS) {
      switch (_currentStep) {
        case 0:
          return 'Agree & Continue';
        case 1:
          return _vpnActive ? 'Continue' : 'Authorize Screen Time';
        case 2:
        default:
          return 'Go to Dashboard';
      }
    }

    switch (_currentStep) {
      case 0:
        return 'Agree & Continue';
      case 1:
        return _certInstalled ? 'Continue' : 'Install Certificate';
      case 2:
        return _vpnActive ? 'Continue' : 'Activate VPN';
      case 3:
        return _a11yActive ? 'Continue' : 'Enable Guardian';
      case 4:
      default:
        return 'Go to Dashboard';
    }
  }

  Future<void> _handleStepAction() async {
    if (Platform.isIOS) {
      switch (_currentStep) {
        case 0:
          _nextStep();
          break;
        case 1:
          if (_vpnActive) {
            _nextStep();
          } else {
            setState(() => _isProcessing = true);
            final success = await IosScreenTimeService.instance.requestAuthorization();
            setState(() {
              _vpnActive = success;
              _isProcessing = false;
            });
            if (success) {
              _nextStep();
            }
          }
          break;
        case 2:
        default:
          await _finishSetup();
          break;
      }
      return;
    }

    switch (_currentStep) {
      case 0:
        _nextStep();
        break;
      case 1:
        if (_certInstalled) {
          _nextStep();
        } else {
          await _installRootCertificate();
        }
        break;
      case 2:
        if (_vpnActive) {
          _nextStep();
        } else {
          await _enableVpn();
        }
        break;
      case 3:
        if (_a11yActive) {
          _nextStep();
        } else {
          await _enableAccessibility();
        }
        break;
      case 4:
      default:
        await _finishSetup();
        break;
    }
  }
}
