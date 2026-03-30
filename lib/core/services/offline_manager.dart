import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whiteapp/core/services/media_cache_service.dart';

class OfflineManager {
  static const String _offlineListKey = 'offline_media_list';

  /// Fetch all tracked offline media 
  static Future<List<Map<String, dynamic>>> getOfflineMedia() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_offlineListKey);
    if (data == null) return [];
    
    final List<dynamic> decoded = json.decode(data);
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Check if specific media is tracked explicitly for offline
  static Future<bool> isTrackedForOffline(String mediaId) async {
    final list = await getOfflineMedia();
    return list.any((item) => item['id'].toString() == mediaId);
  }

  /// Download and explicitly track media
  static Future<void> saveForOffline(Map<String, dynamic> media) async {
    final fileUrl = media['file'];
    if (fileUrl == null) return;
    
    // 1. Physically pull to flutter_cache_manager
    await MediaCacheService.downloadFile(fileUrl);
    
    // 2. Log in SharedPreferences
    final list = await getOfflineMedia();
    
    // Check if already tracked to avoid duplicates
    if (!list.any((item) => item['id'].toString() == media['id'].toString())) {
      list.add(media);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_offlineListKey, json.encode(list));
    }
  }

  /// Delete explicit tracking and native cache references
  static Future<void> removeFromOffline(Map<String, dynamic> media) async {
    final fileUrl = media['file'];
    if (fileUrl != null) {
      // 1. Physically destroy native cache
      await MediaCacheService.removeFile(fileUrl);
    }
    
    // 2. Scrub from SharedPreferences log
    final list = await getOfflineMedia();
    list.removeWhere((item) => item['id'].toString() == media['id'].toString());
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineListKey, json.encode(list));
  }
}
