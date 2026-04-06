// lib/sync/sync_queue.dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';

class SyncQueueItem {
  final int? id;
  final String operation; // 'INSERT', 'UPDATE', 'DELETE'
  final String tableName;
  final String recordId;
  final String payload;
  int retryCount;
  final int? createdAt;
  int? lastAttemptAt;
  String? lastError;

  SyncQueueItem({
    this.id,
    required this.operation,
    required this.tableName,
    required this.recordId,
    required this.payload,
    this.retryCount = 0,
    this.createdAt,
    this.lastAttemptAt,
    this.lastError,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'operation': operation,
        'table_name': tableName,
        'record_id': recordId,
        'payload': payload,
        'retry_count': retryCount,
        'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
        'last_attempt_at': lastAttemptAt,
        'last_error': lastError,
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) => SyncQueueItem(
        id: map['queue_id'],
        operation: map['operation'],
        tableName: map['table_name'],
        recordId: map['record_id'],
        payload: map['payload'],
        retryCount: map['retry_count'] ?? 0,
        createdAt: map['created_at'],
        lastAttemptAt: map['last_attempt_at'],
        lastError: map['last_error'],
      );
}

class SyncQueueManager extends ChangeNotifier {
  static final SyncQueueManager _instance = SyncQueueManager._internal();
  factory SyncQueueManager() => _instance;
  SyncQueueManager._internal();

  DatabaseHelper get _db => DatabaseHelper.instance;

  Timer? _retryTimer;
  bool _isSyncing = false;
  int _pendingCount = 0;
  int _failedCount = 0;

  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  bool get isSyncing => _isSyncing;

  void init() {
    _startRetryTimer();
    _refreshStats();
  }

  /// Tambah item ke antrian sync
  Future<void> enqueue({
    required String operation,
    required String tableName,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db.database;
    final item = SyncQueueItem(
      operation: operation,
      tableName: tableName,
      recordId: recordId,
      payload: jsonEncode(payload),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await db.insert('sync_queue', item.toMap()..remove('id'));
    await _refreshStats();

    if (!_isSyncing) unawaited(processBatch());
  }

  /// Ambil item yang masih pending
  Future<List<SyncQueueItem>> getPendingItems({int limit = AppConstants.syncBatchSize}) async {
    final db = await _db.database;
    final maps = await db.query(
      'sync_queue',
      where: 'retry_count < ?',
      whereArgs: [AppConstants.syncMaxRetry],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return maps.map(SyncQueueItem.fromMap).toList();
  }

  /// Proses batch sync
  Future<void> processBatch() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      final items = await getPendingItems();
      if (items.isEmpty) return;

      debugPrint('🔄 Sync: Memproses ${items.length} item...');

      for (final item in items) {
        await _processItem(item);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('✅ Sync batch selesai');

      // Cek masih ada pending?
      final remaining = await getPendingItems(limit: 1);
      if (remaining.isNotEmpty) {
        Future.delayed(const Duration(seconds: 5), processBatch);
      }
    } catch (e) {
      debugPrint('❌ Sync batch error: $e');
    } finally {
      _isSyncing = false;
      await _refreshStats();
      notifyListeners();
    }
  }

  Future<void> _processItem(SyncQueueItem item) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'sync_queue',
      {'last_attempt_at': now, 'last_error': null},
      where: 'queue_id = ?',
      whereArgs: [item.id],
    );

    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;
      final success = await _sendToServer(item.operation, item.tableName, item.recordId, payload);

      if (success) {
        await db.delete('sync_queue', where: 'queue_id = ?', whereArgs: [item.id]);
        debugPrint('✅ Item ${item.id} synced');
      } else {
        await _handleFailure(item);
      }
    } catch (e) {
      await _handleFailure(item, error: e.toString());
    }
  }

  Future<void> _handleFailure(SyncQueueItem item, {String? error}) async {
    final db = await _db.database;
    final newCount = item.retryCount + 1;

    if (newCount >= AppConstants.syncMaxRetry) {
      // Pindah ke failed queue
      await db.insert('failed_queue', {
        'original_id': item.id,
        'operation': item.operation,
        'table_name': item.tableName,
        'record_id': item.recordId,
        'payload': item.payload,
        'error': error ?? 'Max retry reached',
        'failed_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.delete('sync_queue', where: 'queue_id = ?', whereArgs: [item.id]);
      debugPrint('⚠️ Item ${item.id} failed permanently');
    } else {
      final delaySeconds = AppConstants.syncRetryDelaysSeconds[newCount - 1];
      await db.update(
        'sync_queue',
        {'retry_count': newCount, 'last_error': error},
        where: 'queue_id = ?',
        whereArgs: [item.id],
      );
      debugPrint('⏳ Retry item ${item.id} dalam ${delaySeconds}s (ke-$newCount)');
      Future.delayed(Duration(seconds: delaySeconds), processBatch);
    }
  }

  /// Kirim ke server (HTTP)
  Future<bool> _sendToServer(String method, String table, String id, Map<String, dynamic>? data) async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
    ));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        debugPrint('⚠️ Sync: Token tidak ditemukan, tunda sync');
        return false;
      }

      // Mapping operasi ke tipe sync backend
      String opType = 'send_message';
      if (table == 'messages') opType = 'send_message';
      else if (table == 'contacts' && method == 'UPDATE') opType = (data?['is_paused'] == 1) ? 'pause' : 'unpause';
      else if (table == 'warungs' && method == 'INSERT') opType = 'create_warung';

      final response = await dio.post(
        '/sync/push',
        data: {
          'operations': [
            {
              'type': opType,
              'payload': {
                ...data ?? {},
                'localId': id,
              }
            }
          ]
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final results = response.data['data']['results'] as List;
        return results.isNotEmpty && results[0]['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Sync Network Error: $e');
      return false;
    }
  }

  Future<Map<String, int>> getStats() async {
    final db = await _db.database;
    final pending = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_queue'),
        ) ??
        0;
    final failed = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM failed_queue'),
        ) ??
        0;
    return {'pending': pending, 'failed': failed};
  }

  Future<void> _refreshStats() async {
    final stats = await getStats();
    _pendingCount = stats['pending'] ?? 0;
    _failedCount = stats['failed'] ?? 0;
  }

  Future<void> cleanOldQueue({int daysOld = 7}) async {
    final db = await _db.database;
    final cutoff = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
    await db.delete('sync_queue', where: 'created_at < ?', whereArgs: [cutoff]);
    await db.delete('failed_queue', where: 'failed_at < ?', whereArgs: [cutoff]);
    await _refreshStats();
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing) processBatch();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
