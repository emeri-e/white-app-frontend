import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';

class TelemetryService {
  static final TelemetryService instance = TelemetryService._internal();
  TelemetryService._internal();

  static const String _keyScannedToday = 'telemetry_scanned_today';
  static const String _keyScreensAnalyzed = 'telemetry_screens_analyzed';
  static const String _keyLastResetDate = 'telemetry_last_reset_date';

  /// Increments local scanning telemetry counters
  Future<void> incrementScanCount({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyCounters(prefs);

    final currentScanned = prefs.getInt(_keyScannedToday) ?? 0;
    final currentAnalyzed = prefs.getInt(_keyScreensAnalyzed) ?? 0;

    await prefs.setInt(_keyScannedToday, currentScanned + count);
    await prefs.setInt(_keyScreensAnalyzed, currentAnalyzed + count);
  }

  /// Check if the date has changed since our last reset, and reset daily counters if so
  Future<void> _checkAndResetDailyCounters(SharedPreferences prefs) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final lastReset = prefs.getString(_keyLastResetDate);

    if (lastReset != todayStr) {
      await prefs.setInt(_keyScannedToday, 0);
      await prefs.setString(_keyLastResetDate, todayStr);
    }
  }

  /// Get the current combined stats (local scans + backend blocks)
  Future<Map<String, int>> getDailyStats() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyCounters(prefs);

    int scannedToday = prefs.getInt(_keyScannedToday) ?? 0;
    int screensAnalyzed = prefs.getInt(_keyScreensAnalyzed) ?? 0;
    int blocksToday = 0;

    try {
      final response = await ApiService.get('${Env.apiBase}/api/filtering/stats/today/');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        blocksToday = data['blocks_today'] ?? 0;
      }
    } catch (e) {
      print('TelemetryService: Failed to fetch backend stats: $e');
    }

    return {
      'scanned_today': scannedToday,
      'screens_analyzed': screensAnalyzed,
      'blocks_today': blocksToday,
    };
  }
}
