import 'dart:async';
import 'dart:io';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/features/vpn/services/vpn_service.dart';
import 'package:whiteapp/features/vpn/services/blocklist_service.dart';

class HeartbeatService {
  static final HeartbeatService instance = HeartbeatService._internal();
  HeartbeatService._internal();

  Timer? _heartbeatTimer;

  /// Start periodic heartbeat reporting (sends status every 5 minutes)
  void start() {
    _heartbeatTimer?.cancel();
    // Immediate baseline trigger
    sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      sendHeartbeat();
    });
  }

  /// Stop heartbeat reporting
  void stop() {
    _heartbeatTimer?.cancel();
  }

  /// Send device operational status payload to the server
  Future<void> sendHeartbeat() async {
    try {
      final isVpnEnabled = await VpnService.instance.isVpnRunning();
      final isA11yEnabled = Platform.isAndroid 
          ? await VpnService.instance.isAccessibilityServiceEnabled() 
          : false;
      final blocklistVersion = await BlocklistService.instance.getLocalVersion();

      final payload = {
        'vpn_enabled': isVpnEnabled,
        'accessibility_enabled': isA11yEnabled,
        'camera_roll_monitoring': false,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'current_blocklist_version': blocklistVersion,
        'current_ai_model_version': 1, // Phase 2 defaults
      };

      print('Sending device heartbeat status to backend: $payload');

      final response = await ApiService.post(
        '${Env.apiBase}/filtering/heartbeat/',
        payload,
      );

      if (response.statusCode == 200) {
        print('Heartbeat status received and synced successfully.');
      } else {
        print('Heartbeat sync returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('Heartbeat sync failure: $e');
    }
  }
}
