// lib/sync/background_sync.dart
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../database/database_helper.dart';
import '../sync/sync_queue.dart';
import '../services/warung_service.dart';

@pragma('vm:entry-point')
void waroBackgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('🔁 Background task: $task');
    switch (task) {
      case 'waroBackgroundSync':
        return await _performSync();
      case 'waroExpireWarungs':
        return await _performWarungExpiry();
      case 'waroDailyPulsa':
        return await _performDailyPulsa();
      default:
        return Future.value(false);
    }
  });
}

Future<bool> _performSync() async {
  try {
    await DatabaseHelper.instance.initDatabase();
    final syncManager = SyncQueueManager();
    await syncManager.processBatch();
    await syncManager.cleanOldQueue();
    final stats = await syncManager.getStats();
    debugPrint('📊 Sync stats: pending=${stats['pending']}, failed=${stats['failed']}');
    return true;
  } catch (e) {
    debugPrint('❌ Background sync failed: $e');
    return false;
  }
}

Future<bool> _performWarungExpiry() async {
  try {
    await DatabaseHelper.instance.initDatabase();
    await WarungService().checkAndExpireWarungs();
    debugPrint('✅ Warung expiry check selesai');
    return true;
  } catch (e) {
    debugPrint('❌ Warung expiry failed: $e');
    return false;
  }
}

Future<bool> _performDailyPulsa() async {
  try {
    await DatabaseHelper.instance.initDatabase();
    final db = await DatabaseHelper.instance.database;

    // Cek apakah sudah reset hari ini
    final result = await db.query('pulsa_balance', where: 'id = 1');
    if (result.isEmpty) return false;

    final lastReset = result.first['last_reset_at'] as int?;
    final now = DateTime.now();
    final lastResetDate = lastReset != null
        ? DateTime.fromMillisecondsSinceEpoch(lastReset)
        : DateTime(2000);

    if (now.year == lastResetDate.year &&
        now.month == lastResetDate.month &&
        now.day == lastResetDate.day) {
      return true; // Sudah direset hari ini
    }

    // Tambah 20 pulsa
    final currentBalance = result.first['balance'] as int? ?? 0;
    await db.update('pulsa_balance', {
      'balance': currentBalance + 20,
      'last_reset_at': now.millisecondsSinceEpoch,
    }, where: 'id = 1');

    // Catat transaksi
    await db.insert('pulsa_transactions', {
      'transaction_id': 'daily_${now.millisecondsSinceEpoch}',
      'from_user_id': 'system',
      'to_user_id': 'me',
      'amount': 20,
      'type': 'daily_allotment',
      'created_at': now.millisecondsSinceEpoch,
      'sync_status': 'pending',
    });

    debugPrint('✅ Pulsa harian +20 berhasil');
    return true;
  } catch (e) {
    debugPrint('❌ Daily pulsa failed: $e');
    return false;
  }
}
