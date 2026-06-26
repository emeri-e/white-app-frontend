import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/features/ai/services/ai_model_updater.dart';
import 'package:whiteapp/features/ai/services/camera_roll_service.dart';

class BlockReporterService {
  static final BlockReporterService instance = BlockReporterService._internal();
  BlockReporterService._internal();

  static const _channel = MethodChannel('com.whiteapp/vpn');
  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Starts the 60-second periodic upload and heartbeat timer.
  void startPeriodicReporting() {
    if (kIsWeb) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      triggerSync();
    });
    // Trigger immediately on startup
    triggerSync();
  }

  /// Stops the periodic timer.
  void stopPeriodicReporting() {
    if (kIsWeb) return;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Triggers a manual sync of both block events and device heartbeats.
  Future<void> triggerSync() async {
    if (kIsWeb) return;
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await reportBlockEvents();
      await sendHeartbeat();
    } catch (e) {
      print('BlockReporterService: Error in periodic sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Retrieves, parses, and batch uploads local block events to the backend.
  Future<void> reportBlockEvents() async {
    try {
      final String? jsonStr = await _channel.invokeMethod<String>('flushNativeBlockEvents');
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]') {
        return;
      }

      final List<dynamic> eventsList = json.decode(jsonStr);
      if (eventsList.isEmpty) return;

      print('BlockReporterService: Flushing ${eventsList.length} native block events to backend...');

      // Map the events to match BlockEventSerializer fields exactly
      final formattedEvents = eventsList.map((e) {
        final rawBlockType = e['block_type'] ?? 'ai_image';
        String blockType = rawBlockType;
        if (rawBlockType == 'ai_proxy' || rawBlockType == 'ai_inline') {
          blockType = 'ai_image';
        }

        final rawUrl = e['url'] ?? '';
        final url = (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
            ? rawUrl
            : '';

        return {
          'block_type': blockType,
          'app_name': e['app_name'] ?? 'UnknownApp',
          'domain': e['domain'] ?? '',
          'url': url,
          'ai_class_label': e['ai_class_label'] ?? 'GENITALIA_EXPOSED',
          'confidence_score': e['confidence_score'] ?? 0.85,
          'timestamp': e['timestamp'] ?? DateTime.now().toUtc().toIso8601String(),
        };
      }).toList();

      final url = '${Env.apiBase}/filtering/block-events/';
      final response = await ApiService.post(url, {
        'events': formattedEvents,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('BlockReporterService: Batch block events uploaded successfully.');
      } else {
        throw Exception('Failed to upload block events: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('BlockReporterService: Failed to report block events: $e');
    }
  }

  /// Reports current device shield and filter status back to backend.
  Future<void> sendHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Determine feature states
      final bool vpnActive = await _channel.invokeMethod<bool>('isVpnRunning') ?? false;
      final bool a11yActive = await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      final bool cameraRollActive = await CameraRollService.instance.isMonitoring();

      // Retrieve version numbers
      final int blocklistVer = prefs.getInt('current_blocklist_version') ?? 1;
      final int aiModelVer = await AIModelUpdater.instance.getCurrentVersion();

      final payload = {
        'vpn_enabled': vpnActive,
        'accessibility_enabled': a11yActive,
        'camera_roll_monitoring': cameraRollActive,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'current_blocklist_version': blocklistVer,
        'current_ai_model_version': aiModelVer,
      };

      final url = '${Env.apiBase}/filtering/heartbeat/';
      final response = await ApiService.post(url, payload);

      if (response.statusCode == 200) {
        print('BlockReporterService: Heartbeat acknowledged by backend.');
      } else {
        throw Exception('Failed to send heartbeat: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('BlockReporterService: Failed to report heartbeat: $e');
    }
  }
}
