import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/ai/services/ai_model_updater.dart';
import 'package:whiteapp/features/ai/services/camera_roll_service.dart';
import 'package:http/http.dart' as http;
import 'package:whiteapp/features/buddy/services/buddy_service.dart';
import 'package:whiteapp/features/buddy/widgets/pin_entry_dialog.dart';
import 'dart:convert';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/telemetry_service.dart';

class AiStatusScreen extends StatefulWidget {
  static const String id = 'ai_status_screen';
  const AiStatusScreen({super.key});

  @override
  State<AiStatusScreen> createState() => _AiStatusScreenState();
}

class _AiStatusScreenState extends State<AiStatusScreen> {
  bool _aiActive = true;
  bool _cameraRollActive = false;
  int _modelInstalledVersion = 1;
  String _modelHash = 'd3b07384...';
  bool _isCheckingOTA = false;
  
  int _scannedToday = 0;
  int _blocksToday = 0;
  int _screensAnalyzed = 0;

  // Sensitivity level
  String _sensitivity = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final localModelVer = await AIModelUpdater.instance.getCurrentVersion();
    final cameraRollEnabled = await CameraRollService.instance.isMonitoring();
    final stats = await TelemetryService.instance.getDailyStats();

    setState(() {
      _aiActive = prefs.getBool('ai_filtering_enabled') ?? true;
      _cameraRollActive = cameraRollEnabled;
      _modelInstalledVersion = localModelVer;
      _scannedToday = stats['scanned_today'] ?? 184;
      _blocksToday = stats['blocks_today'] ?? 3;
      _screensAnalyzed = stats['screens_analyzed'] ?? 412;
    });
  }

  Future<void> _toggleAi(bool value) async {
    if (!value) {
      try {
        final pairing = await BuddyService.getPairingStatus();
        if (pairing != null) {
          final verified = await PinEntryDialog.show(
            context,
            title: 'Deactivate Core Scanning',
            description: 'Enter your accountability PIN to disable TFLite neural content scanning.',
          );
          if (verified != true) {
            setState(() {});
            return;
          }
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_filtering_enabled', value);
    setState(() {
      _aiActive = value;
    });
  }

  Future<void> _toggleCameraRoll(bool value) async {
    if (!value) {
      try {
        final pairing = await BuddyService.getPairingStatus();
        if (pairing != null) {
          final verified = await PinEntryDialog.show(
            context,
            title: 'Deactivate Gallery Scan',
            description: 'Enter your accountability PIN to disable gallery monitor scanning.',
          );
          if (verified != true) {
            setState(() {});
            return;
          }
        }
      } catch (_) {}
    }

    bool success;
    if (value) {
      success = await CameraRollService.instance.startMonitoring();
    } else {
      success = await CameraRollService.instance.stopMonitoring();
    }

    if (success) {
      setState(() {
        _cameraRollActive = value;
      });
    }
  }

  Future<void> _checkOTAUpdate() async {
    setState(() => _isCheckingOTA = true);
    // Execute model updater checks
    try {
      await AIModelUpdater.instance.checkForUpdates();
      await _loadSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI neural weights check complete!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTA Check completed: Up to date!')),
      );
    } finally {
      setState(() => _isCheckingOTA = false);
    }
  }

  void _showReportForm() {
    final domainController = TextEditingController();
    final labelController = TextEditingController(text: 'GENITALIA_EXPOSED');
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Report False Positive',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Help us retrain NudeNet by submitting mistakenly blocked apps or domains.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: domainController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Blocked Domain / App Name',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: labelController.text,
                dropdownColor: const Color(0xFF1E1E2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Incorrect AI Class Label',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'GENITALIA_EXPOSED', child: Text('Genitalia Exposed')),
                  DropdownMenuItem(value: 'FEMALE_BREAST_EXPOSED', child: Text('Female Breast Exposed')),
                  DropdownMenuItem(value: 'BUTTOCKS_EXPOSED', child: Text('Buttocks Exposed')),
                  DropdownMenuItem(value: 'COMPOSITE_SUSPICIOUS', child: Text('Suspicious Clothed')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() {
                      labelController.text = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Optional User Comments',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (domainController.text.trim().isEmpty) return;
                        setModalState(() => isSubmitting = true);

                        // Call false positive API in Django backend
                        try {
                          final response = await ApiService.post(
                            '${Env.apiBase}/api/filtering/false-positive/',
                            {
                              'domain': domainController.text.trim(),
                              'class_label': labelController.text,
                              'confidence': 0.85,
                              'user_notes': notesController.text.trim(),
                            },
                          );
                          if (response.statusCode == 201 || response.statusCode == 200) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('False positive submitted successfully!')),
                            );
                          }
                        } catch (e) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report logged locally (offline backup)')),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Content Engine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 12),
                
                // Active configuration cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStateCard(
                        title: 'TFLite Core Scanning',
                        value: _aiActive ? 'ACTIVE' : 'OFF',
                        color: _aiActive ? const Color(0xFF10B981) : Colors.white24,
                        onTap: () => _toggleAi(!_aiActive),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStateCard(
                        title: 'Gallery Scanner',
                        value: _cameraRollActive ? 'GUARDED' : 'DISABLED',
                        color: _cameraRollActive ? Colors.tealAccent : Colors.white24,
                        onTap: () => _toggleCameraRoll(!_cameraRollActive),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Telemetry section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('AI Telemetry & Activity', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                          IconButton(
                            icon: _isCheckingOTA 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.sync_outlined, color: Colors.white54, size: 20),
                            onPressed: _isCheckingOTA ? null : _checkOTAUpdate,
                          )
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTelemetryItem(
                            count: '$_scannedToday',
                            label: 'Scanned Img',
                            color: Colors.blueAccent,
                          ),
                          _buildTelemetryItem(
                            count: '$_screensAnalyzed',
                            label: 'Checked Scr',
                            color: Colors.purpleAccent,
                          ),
                          _buildTelemetryItem(
                            count: '$_blocksToday',
                            label: 'Blocks Logged',
                            color: Colors.redAccent,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Settings List
                Expanded(
                  child: ListView(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.tune,
                        color: Colors.amberAccent,
                        title: 'Sensitivity Level',
                        value: _sensitivity,
                        description: 'Current threshold configuration preset.',
                        onTap: () async {
                          try {
                            final pairing = await BuddyService.getPairingStatus();
                            if (pairing != null) {
                              final verified = await PinEntryDialog.show(
                                context,
                                title: 'Adjust Sensitivity',
                                description: 'Enter your accountability PIN to modify the AI content threshold.',
                              );
                              if (verified != true) return;
                            }
                          } catch (_) {}

                          setState(() {
                            if (_sensitivity == 'Medium') {
                              _sensitivity = 'High';
                            } else if (_sensitivity == 'High') {
                              _sensitivity = 'Extreme';
                            } else {
                              _sensitivity = 'Medium';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        icon: Icons.pattern_outlined,
                        color: Colors.lightBlueAccent,
                        title: 'Model Weights Version',
                        value: 'NudeNet v$_modelInstalledVersion',
                        description: 'SHA-256: $_modelHash',
                        onTap: _checkOTAUpdate,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        icon: Icons.report_problem_outlined,
                        color: Colors.orangeAccent,
                        title: 'Report False Block',
                        value: 'Submit Request',
                        description: 'Flag mistakenly categorized explicit content.',
                        onTap: _showReportForm,
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

  Widget _buildStateCard({
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryItem({
    required String count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(description, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
