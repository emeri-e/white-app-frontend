import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/constants/env.dart';
import 'package:whiteapp/features/vpn/models/block_event.dart';
import 'package:whiteapp/features/vpn/services/blocklist_service.dart';

class BlockReporterService {
  static final BlockReporterService instance = BlockReporterService._internal();
  BlockReporterService._internal();

  Timer? _flushTimer;
  bool _isFlushing = false;

  /// Start periodic reporting timer (flushes every 60 seconds)
  void start() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      flushQueuedEvents();
    });
  }

  /// Stop the reporting timer
  void stop() {
    _flushTimer?.cancel();
  }

  /// Initialize database table for queued events if not already present
  Future<void> _ensureQueueTableCreated(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS queued_block_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        block_type TEXT,
        app_name TEXT,
        domain TEXT,
        url TEXT,
        ai_class_label TEXT,
        confidence_score REAL,
        timestamp INTEGER
      )
    ''');
  }

  /// Record a block event. If offline, queues it locally in SQLite.
  Future<void> reportBlock(BlockEvent event) async {
    try {
      final db = await BlocklistService.instance.database;
      await _ensureQueueTableCreated(db);

      await db.insert('queued_block_events', event.toLocalMap());
      print('Logged block event to local queue: ${event.domain}');

      // Trigger an immediate asynchronous attempt to flush
      flushQueuedEvents();
    } catch (e) {
      print('Failed to record block event: $e');
    }
  }

  /// Flush all queued block events from SQLite to the server in a single batch
  Future<void> flushQueuedEvents() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      final db = await BlocklistService.instance.database;
      await _ensureQueueTableCreated(db);

      final List<Map<String, dynamic>> maps = await db.query(
        'queued_block_events',
        orderBy: 'id ASC',
        limit: 100, // Batch limit per payload
      );

      if (maps.isEmpty) {
        _isFlushing = false;
        return;
      }

      print('Flushing ${maps.length} queued block events to backend...');

      final List<BlockEvent> events = maps.map((m) => BlockEvent.fromLocalMap(m)).toList();
      final List<Map<String, dynamic>> jsonEvents = events.map((e) => e.toJson()).toList();

      final response = await ApiService.post(
        '${Env.apiBase}/filtering/block-events/',
        {'events': jsonEvents},
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Success! Remove those events from the local SQLite queue
        final List<int> ids = maps.map((m) => m['id'] as int).toList();
        await db.delete(
          'queued_block_events',
          where: 'id IN (${ids.join(",")})',
        );
        print('Successfully flushed and cleared ${ids.length} block events.');
      } else {
        print('Failed to upload events. Server returned: ${response.statusCode}');
      }
    } catch (e) {
      print('Error flushing block events: $e');
    } finally {
      _isFlushing = false;
    }
  }
}
