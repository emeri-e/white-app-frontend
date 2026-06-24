import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:crypto/crypto.dart';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/features/vpn/services/ios_screentime_service.dart';

class BlocklistService {
  static final BlocklistService instance = BlocklistService._internal();
  BlocklistService._internal();

  Database? _db;

  // Shared OTA blocklist verification key matching backend
  static const String _sharedSecret = "whiteapp_shared_secure_network_secret_2026";

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, 'whiteapp_blocklist.db');

    return await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE blocked_domains (
            domain TEXT UNIQUE PRIMARY KEY,
            category TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE blocked_keywords (
            keyword TEXT UNIQUE PRIMARY KEY,
            category TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE blocked_urls (
            url TEXT UNIQUE PRIMARY KEY,
            category TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE whitelisted_domains (
            domain TEXT UNIQUE PRIMARY KEY,
            reason TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sensitivity_configs (
            class_label TEXT UNIQUE PRIMARY KEY,
            category TEXT,
            confidence_threshold REAL,
            is_blocking INTEGER,
            composite_only INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE meta_info (
            key TEXT UNIQUE PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  /// Get locally stored version number from database meta_info table
  Future<int> getLocalVersion() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meta_info',
      where: 'key = ?',
      whereArgs: ['blocklist_version'],
    );
    if (maps.isEmpty) return 0;
    return int.parse(maps.first['value'].toString());
  }

  /// Check backend for newer blocklist version
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final currentVersion = await getLocalVersion();
      final response = await ApiService.get(
        '${Env.apiBase}/filtering/blocklist/check-update/?current_version=$currentVersion',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['update_available'] == true) {
          return data; // contains version, delta_url, signature
        }
      }
    } catch (e) {
      print('Failed to check blocklist update: $e');
    }
    return null;
  }

  /// Synchronize with backend to fetch the latest signed blocklist and apply it
  Future<bool> syncBlocklist() async {
    try {
      final updateData = await checkForUpdate();
      if (updateData == null) {
        print('Blocklist is already up to date.');
        return true;
      }

      final String deltaUrl = updateData['delta_url'] ?? '';
      final String signature = updateData['signature'] ?? '';
      final int newVersion = updateData['version'] ?? 0;

      if (deltaUrl.isEmpty) return false;

      print('Downloading newer blocklist delta from $deltaUrl...');
      final http.Response res = await http.get(Uri.parse(deltaUrl));
      if (res.statusCode != 200) {
        print('Failed to download delta package file.');
        return false;
      }

      final String jsonBody = res.body;

      // Verify cryptographic signature of the downloaded package
      final bool isValid = _verifyHmacSignature(jsonBody, signature);
      if (!isValid) {
        print('CRITICAL: Blocklist delta HMAC signature verification failed!');
        return false;
      }

      print('Signature verified! Applying blocklist update payload...');
      final Map<String, dynamic> payload = json.decode(jsonBody);
      await _applyUpdatePayload(payload, newVersion);
      return true;
    } catch (e) {
      print('Failed blocklist sync: $e');
      return false;
    }
  }

  /// Full database re-synchronization (used on first install)
  Future<bool> forceFullSync() async {
    try {
      print('Fetching complete blocklist data from server...');
      final response = await ApiService.get('${Env.apiBase}/filtering/blocklist/full/');
      if (response.statusCode != 200) return false;

      final Map<String, dynamic> payload = json.decode(response.body);
      final int version = payload['version'] ?? 1;

      await _applyUpdatePayload(payload, version);
      return true;
    } catch (e) {
      print('Full sync failure: $e');
      return false;
    }
  }

  /// Apply the downloaded blocklist package in a single SQLite Transaction
  Future<void> _applyUpdatePayload(Map<String, dynamic> payload, int version) async {
    final db = await database;
    final List<dynamic> domains = payload['domains'] ?? [];
    final List<dynamic> keywords = payload['keywords'] ?? [];
    final List<dynamic> urls = payload['urls'] ?? [];
    final List<dynamic> whitelist = payload['whitelist'] ?? [];
    final List<dynamic> sensitivity = payload['sensitivity'] ?? [];

    // Save domains to a local text file to avoid SQLite performance bottleneck
    try {
      final dbPath = await getDatabasesPath();
      final txtFile = File(path_pkg.join(dbPath, 'blocked_domains.txt'));
      final content = domains.map((d) => d.toString().trim().toLowerCase()).join('\n');
      await txtFile.writeAsString(content);
      print('Successfully wrote ${domains.length} domains to blocked_domains.txt');
    } catch (e) {
      print('Failed to write blocked_domains.txt: $e');
    }

    await db.transaction((txn) async {
      // Clear current lists (except blocked_domains since we don't store it in SQLite anymore)
      await txn.delete('blocked_keywords');
      await txn.delete('blocked_urls');
      await txn.delete('whitelisted_domains');
      await txn.delete('sensitivity_configs');

      // Populate keywords
      for (final kw in keywords) {
        await txn.insert('blocked_keywords', {
          'keyword': kw.toString(),
          'category': 'nudity',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Populate URL paths
      for (final url in urls) {
        await txn.insert('blocked_urls', {
          'url': url.toString(),
          'category': 'nudity',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Populate allowed exceptions whitelist
      for (final wl in whitelist) {
        await txn.insert('whitelisted_domains', {
          'domain': wl.toString(),
          'reason': 'Admin Whitelisted',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Populate sensitivity configurations
      for (final sens in sensitivity) {
        await txn.insert('sensitivity_configs', {
          'class_label': sens['class_label'].toString(),
          'category': sens['category'].toString(),
          'confidence_threshold': (sens['confidence_threshold'] as num).toDouble(),
          'is_blocking': sens['is_blocking'] == true ? 1 : 0,
          'composite_only': sens['composite_only'] == true ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Update local version meta info tag
      await txn.insert('meta_info', {
        'key': 'blocklist_version',
        'value': version.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    if (Platform.isIOS) {
      final List<String> domainsList = await getBlockedDomains();
      await IosScreenTimeService.instance.updateBlockedDomains(domainsList);
    }

    print('Blocklist SQLite updated successfully to v$version!');
  }

  /// Cryptographic signature verification using HMAC-SHA256
  bool _verifyHmacSignature(String jsonBody, String signature) {
    try {
      final keyBytes = utf8.encode(_sharedSecret);
      final bodyBytes = utf8.encode(jsonBody);

      final hmacSha256 = Hmac(sha256, keyBytes);
      final digest = hmacSha256.convert(bodyBytes);

      // Compare digests
      return digest.toString() == signature;
    } catch (e) {
      print('Hmac verification error: $e');
      return false;
    }
  }

  /// Load complete list of blocked domains from local text file
  Future<List<String>> getBlockedDomains() async {
    try {
      final dbPath = await getDatabasesPath();
      final txtFile = File(path_pkg.join(dbPath, 'blocked_domains.txt'));
      if (await txtFile.exists()) {
        final content = await txtFile.readAsString();
        return content
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('Failed to read blocked domains file: $e');
    }
    return [];
  }

  /// Load complete list of allowed whitelisted domains
  Future<List<String>> getWhitelistedDomains() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('whitelisted_domains');
    return maps.map((m) => m['domain'].toString()).toList();
  }
}
