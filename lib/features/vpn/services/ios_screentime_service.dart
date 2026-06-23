import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class IosScreenTimeService {
  static const MethodChannel _channel = MethodChannel('com.whiteapp/screentime');

  static final IosScreenTimeService instance = IosScreenTimeService._internal();
  IosScreenTimeService._internal();

  /// Request iOS system permission for Screen Time FamilyControls
  Future<bool> requestAuthorization() async {
    if (!Platform.isIOS) return false;
    try {
      final bool success = await _channel.invokeMethod('requestAuthorization');
      print('IosScreenTimeService: requestAuthorization result -> $success');
      return success;
    } on PlatformException catch (e) {
      print('IosScreenTimeService: requestAuthorization failed: ${e.message}');
      return false;
    }
  }

  /// Sync blocklist domains list directly to the system-wide iOS ManagedSettingsStore
  Future<bool> updateBlockedDomains(List<String> domains) async {
    if (!Platform.isIOS) return false;
    try {
      final bool success = await _channel.invokeMethod('updateBlockedDomains', {
        'domains': domains,
      });
      print('IosScreenTimeService: updateBlockedDomains of size ${domains.length} -> $success');
      return success;
    } on PlatformException catch (e) {
      print('IosScreenTimeService: updateBlockedDomains failed: ${e.message}');
      return false;
    }
  }

  /// Get current FamilyControls authorization status
  Future<String> getStatus() async {
    if (!Platform.isIOS) return 'unsupported';
    try {
      final String status = await _channel.invokeMethod('getStatus');
      return status;
    } on PlatformException catch (e) {
      print('IosScreenTimeService: getStatus failed: ${e.message}');
      return 'denied';
    }
  }
}
