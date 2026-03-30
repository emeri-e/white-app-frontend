import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MediaCacheService {
  static final DefaultCacheManager cacheManager = DefaultCacheManager();

  static Future<void> downloadFile(String url) async {
    await cacheManager.downloadFile(url);
  }

  static Future<String?> getCachedFilePath(String url) async {
    final fileInfo = await cacheManager.getFileFromCache(url);
    if (fileInfo != null) {
      return fileInfo.file.path;
    }
    return null;
  }
  
  static Future<bool> isCached(String url) async {
    final fileInfo = await cacheManager.getFileFromCache(url);
    return fileInfo != null;
  }
  
  static Future<void> removeFile(String url) async {
    await cacheManager.removeFile(url);
  }
}
