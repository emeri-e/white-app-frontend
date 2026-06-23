import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraRollService {
  static const MethodChannel _channel = MethodChannel('com.whiteapp/vpn');

  static final CameraRollService instance = CameraRollService._internal();
  CameraRollService._internal();

  /// Requests the appropriate gallery/storage permission for media scanning.
  Future<bool> requestStoragePermission() async {
    // Under Android 13 (API 33+), we must check Permission.photos, otherwise Permission.storage
    if (await Permission.photos.request().isGranted) {
      return true;
    }
    
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Request permissions and start monitoring camera roll.
  Future<bool> startMonitoring() async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      print('CameraRollService: Permission denied, cannot start monitoring.');
      return false;
    }

    try {
      final bool success = await _channel.invokeMethod('startCameraRollMonitoring');
      print('CameraRollService: Started native monitor: $success');
      return success;
    } on PlatformException catch (e) {
      print('CameraRollService error starting: ${e.message}');
      return false;
    }
  }

  /// Stop monitoring camera roll.
  Future<bool> stopMonitoring() async {
    try {
      final bool success = await _channel.invokeMethod('stopCameraRollMonitoring');
      print('CameraRollService: Stopped native monitor: $success');
      return success;
    } on PlatformException catch (e) {
      print('CameraRollService error stopping: ${e.message}');
      return false;
    }
  }

  /// Checks if the native monitor is currently active.
  Future<bool> isMonitoring() async {
    try {
      final bool active = await _channel.invokeMethod('isCameraRollMonitoring');
      return active;
    } on PlatformException catch (e) {
      print('CameraRollService error checking status: ${e.message}');
      return false;
    }
  }
}
