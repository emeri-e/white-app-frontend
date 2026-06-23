import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:whiteapp/features/ai/services/block_reporter_service.dart';

class VpnService {
  static const MethodChannel _channel = MethodChannel('com.whiteapp/vpn');
  static const EventChannel _eventChannel = EventChannel('com.whiteapp/vpn_status');

  static final VpnService instance = VpnService._internal();
  VpnService._internal();

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  void init() {
    if (kIsWeb) {
      _statusController.add('connected'); // Mock active on Web
      return;
    }
    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        _statusController.add(event.toString());
      },
      onError: (error) {
        _statusController.addError(error);
      },
    );

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onKeywordDetected') {
        final arguments = call.arguments;
        if (arguments is Map) {
          final keyword = arguments['keyword']?.toString() ?? '';
          final appName = arguments['appName']?.toString() ?? '';
          print('Keyword matched via native channel: $keyword in $appName');
          try {
            await BlockReporterService.instance.triggerSync();
          } catch (_) {}
        }
      }
    });
  }

  /// Start the native Android VPN foreground service
  Future<bool> startVpn() async {
    if (kIsWeb) return true;
    try {
      final bool success = await _channel.invokeMethod('startVpn');
      return success;
    } on PlatformException catch (e) {
      print('VPN failed to start: ${e.message}');
      return false;
    }
  }

  /// Stop the native Android VPN service
  Future<bool> stopVpn() async {
    if (kIsWeb) return true;
    try {
      final bool success = await _channel.invokeMethod('stopVpn');
      return success;
    } on PlatformException catch (e) {
      print('VPN failed to stop: ${e.message}');
      return false;
    }
  }

  /// Get current VPN operational status
  Future<bool> isVpnRunning() async {
    if (kIsWeb) return true;
    try {
      final bool running = await _channel.invokeMethod('isVpnRunning');
      return running;
    } on PlatformException catch (e) {
      print('Failed to check VPN state: ${e.message}');
      return false;
    }
  }

  /// Install self-generated SSL/TLS root CA cert to the Android user credentials
  Future<bool> installCertificate() async {
    if (kIsWeb) return true;
    try {
      final bool success = await _channel.invokeMethod('installCertificate');
      return success;
    } on PlatformException catch (e) {
      print('Cert install triggered exception: ${e.message}');
      return false;
    }
  }

  /// Check programmatically if the custom CA certificate is installed and trusted
  Future<bool> isCertificateInstalled() async {
    if (kIsWeb) return true;
    try {
      final bool installed = await _channel.invokeMethod('isCertificateInstalled');
      return installed;
    } on PlatformException catch (e) {
      print('Failed to check certificate status: ${e.message}');
      return false;
    }
  }

  /// Check if the Android version requires manual CA certificate installation (Android 11+)
  Future<bool> requiresManualInstallation() async {
    if (kIsWeb) return false;
    try {
      final bool manual = await _channel.invokeMethod('requiresManualInstallation');
      return manual;
    } on PlatformException catch (e) {
      print('Failed to check manual install requirement: ${e.message}');
      return false;
    }
  }

  /// Check if the custom Accessibility Service is enabled in settings
  Future<bool> isAccessibilityServiceEnabled() async {
    if (kIsWeb) return true;
    try {
      final bool enabled = await _channel.invokeMethod('isAccessibilityEnabled');
      return enabled;
    } on PlatformException catch (e) {
      print('Failed to check accessibility status: ${e.message}');
      return false;
    }
  }

  /// Open Android Accessibility Settings deep link
  Future<void> openAccessibilitySettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print('Failed to open settings: ${e.message}');
    }
  }
}
