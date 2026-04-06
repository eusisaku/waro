// lib/services/pause_chat_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

enum PauseReason {
  digitalDetox('Digital Detox', 'Istirahat dari notifikasi'),
  needFocus('Butuh Fokus', 'Tidak ingin terganggu saat kerja/belajar'),
  holiday('Sedang Liburan', 'Akan aktif lagi setelah liburan'),
  conflict('Butuh Jeda', 'Sedang ada ketegangan, butuh waktu tenang'),
  custom('Lainnya', 'Alasan pribadi');

  const PauseReason(this.title, this.description);
  final String title;
  final String description;
}

class PausedContact {
  final String contactId;
  final String contactName;
  final DateTime pauseUntil;
  final PauseReason reason;
  final String? customReason;
  final bool autoResume;
  final int pendingMessagesCount;

  PausedContact({
    required this.contactId,
    required this.contactName,
    required this.pauseUntil,
    required this.reason,
    this.customReason,
    this.autoResume = true,
    this.pendingMessagesCount = 0,
  });

  Duration get remainingTime => pauseUntil.difference(DateTime.now());
  bool get isExpired => DateTime.now().isAfter(pauseUntil);

  String get formattedRemaining {
    if (isExpired) return 'Sudah berakhir';
    final d = remainingTime;
    if (d.inDays > 0) return '${d.inDays} hari lagi';
    if (d.inHours > 0) return '${d.inHours} jam lagi';
    if (d.inMinutes > 0) return '${d.inMinutes} menit lagi';
    return '${d.inSeconds} detik lagi';
  }
}

class PauseChatService extends ChangeNotifier {
  static final PauseChatService _instance = PauseChatService._internal();
  factory PauseChatService() => _instance;
  PauseChatService._internal();

  DatabaseHelper get _db => DatabaseHelper.instance;
  Timer? _checkerTimer;

  List<PausedContact> _pausedContacts = [];
  List<PausedContact> get pausedContacts => _pausedContacts;

  void init() {
    _startPauseChecker();
    _checkExpiredPauses();
  }

  // ===== PAUSE CONTACT =====

  /// Pause chat dengan seseorang (1-7 hari)
  Future<void> pauseContact({
    required String contactId,
    required String contactName,
    required int durationDays,
    required PauseReason reason,
    String? customReason,
    bool autoResume = true,
  }) async {
    final db = await _db.database;
    final pauseUntil = DateTime.now().add(Duration(days: durationDays));

    await db.insert(
      'paused_contacts',
      {
        'contact_id': contactId,
        'contact_name': contactName,
        'pause_until': pauseUntil.millisecondsSinceEpoch,
        'reason': reason.name,
        'custom_reason': customReason,
        'auto_resume': autoResume ? 1 : 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Kirim notifikasi sistem ke kontak
    await _sendPauseNotification(
      contactId: contactId,
      contactName: contactName,
      durationDays: durationDays,
      reason: reason,
      customReason: customReason,
    );

    await _refreshList();
    debugPrint('🔕 Pause chat dengan $contactName selama $durationDays hari');
  }

  /// Akhiri pause lebih awal
  Future<void> unpauseContact(String contactId) async {
    final db = await _db.database;

    final pauseData = await db.query(
      'paused_contacts',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );

    if (pauseData.isEmpty) return;
    final contactName = pauseData.first['contact_name'] as String;

    await db.delete('paused_contacts', where: 'contact_id = ?', whereArgs: [contactId]);
    await _sendUnpauseNotification(contactId, contactName);
    await _deliverPendingMessages(contactId);
    await _refreshList();

    debugPrint('🔔 Pause dengan $contactName dihentikan');
  }

  /// Cek apakah kontak sedang dipause
  Future<bool> isContactPaused(String contactId) async {
    final db = await _db.database;
    final result = await db.query(
      'paused_contacts',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );

    if (result.isEmpty) return false;

    final pauseUntil = DateTime.fromMillisecondsSinceEpoch(result.first['pause_until'] as int);
    if (DateTime.now().isAfter(pauseUntil)) {
      await db.delete('paused_contacts', where: 'contact_id = ?', whereArgs: [contactId]);
      return false;
    }
    return true;
  }

  /// Dapatkan data pause kontak tertentu
  Future<PausedContact?> getPausedContact(String contactId) async {
    final db = await _db.database;
    final results = await db.query(
      'paused_contacts',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
    if (results.isEmpty) return null;
    return _mapToPausedContact(results.first);
  }

  /// Dapatkan semua kontak yang dipause
  Future<List<PausedContact>> getPausedContacts() async {
    final db = await _db.database;
    final results = await db.query('paused_contacts', orderBy: 'pause_until ASC');
    final list = <PausedContact>[];
    for (final row in results) {
      final pending = await _getPendingCount(row['contact_id'] as String);
      list.add(_mapToPausedContact(row, pendingCount: pending));
    }
    return list;
  }

  PausedContact _mapToPausedContact(Map<String, dynamic> row, {int pendingCount = 0}) {
    final reasonName = row['reason'] as String;
    final reason = PauseReason.values.firstWhere(
      (r) => r.name == reasonName,
      orElse: () => PauseReason.digitalDetox,
    );
    return PausedContact(
      contactId: row['contact_id'] as String,
      contactName: row['contact_name'] as String,
      pauseUntil: DateTime.fromMillisecondsSinceEpoch(row['pause_until'] as int),
      reason: reason,
      customReason: row['custom_reason'] as String?,
      autoResume: (row['auto_resume'] as int) == 1,
      pendingMessagesCount: pendingCount,
    );
  }

  /// Simpan pesan ke pending (saat kontak dipause)
  Future<void> storePendingMessage({
    required String contactId,
    required String senderId,
    required String senderName,
    required String message,
    bool isUrgent = false,
  }) async {
    final db = await _db.database;
    await db.insert('pending_messages', {
      'contact_id': contactId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'is_urgent': isUrgent ? 1 : 0,
      'sent_at': DateTime.now().millisecondsSinceEpoch,
    });
    await db.rawUpdate(
      'UPDATE paused_contacts SET pending_messages_count = pending_messages_count + 1 WHERE contact_id = ?',
      [contactId],
    );
    await _refreshList();
  }

  /// Pause semua kontak (digital detox mode)
  Future<void> pauseAllContacts({required int durationDays, String? excludeContactId}) async {
    final db = await _db.database;
    final contacts = await db.query('contacts');
    for (final contact in contacts) {
      final cid = contact['contact_id'] as String;
      if (excludeContactId != null && cid == excludeContactId) continue;
      await pauseContact(
        contactId: cid,
        contactName: contact['name'] as String,
        durationDays: durationDays,
        reason: PauseReason.digitalDetox,
      );
    }
  }

  // ===== PRIVATE HELPERS =====

  Future<void> _sendPauseNotification({
    required String contactId,
    required String contactName,
    required int durationDays,
    required PauseReason reason,
    String? customReason,
  }) async {
    final db = await _db.database;
    final reasonText = customReason ?? reason.description;
    final untilDate = DateTime.now().add(Duration(days: durationDays));
    final content =
        '🔕 [SISTEM WARO]\n$contactName sedang mem-pause chat dengan Anda selama $durationDays hari.\n\nAlasan: $reasonText\n\nPesan Anda tetap disimpan & terkirim setelah pause berakhir.\nPause berakhir: ${_formatDate(untilDate)}';

    await db.insert('messages', {
      'message_id': 'sys_pause_${DateTime.now().millisecondsSinceEpoch}',
      'recipient_id': contactId,
      'sender_id': 'system',
      'sender_name': 'Sistem WARO',
      'content': content,
      'message_type': 'system_notification',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'synced',
    });
  }

  Future<void> _sendUnpauseNotification(String contactId, String contactName) async {
    final db = await _db.database;
    await db.insert('messages', {
      'message_id': 'sys_unpause_${DateTime.now().millisecondsSinceEpoch}',
      'recipient_id': contactId,
      'sender_id': 'system',
      'sender_name': 'Sistem WARO',
      'content':
          '🔔 [SISTEM WARO]\n$contactName telah mengakhiri mode Pause.\n\nSekarang Anda bisa chat kembali. Pesan yang dikirim selama pause akan segera masuk.',
      'message_type': 'system_notification',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'synced',
    });
  }

  Future<void> _deliverPendingMessages(String contactId) async {
    final db = await _db.database;
    final pending = await db.query(
      'pending_messages',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'sent_at ASC',
    );
    for (final msg in pending) {
      await db.insert('messages', {
        'message_id': 'delayed_${DateTime.now().millisecondsSinceEpoch}_${msg['id']}',
        'recipient_id': contactId,
        'sender_id': msg['sender_id'],
        'sender_name': msg['sender_name'],
        'content': msg['message'],
        'message_type': 'text',
        'sent_at': msg['sent_at'],
        'delivered_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'synced',
      });
    }
    await db.delete('pending_messages', where: 'contact_id = ?', whereArgs: [contactId]);
  }

  Future<int> _getPendingCount(String contactId) async {
    final db = await _db.database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
              'SELECT COUNT(*) FROM pending_messages WHERE contact_id = ?', [contactId]),
        ) ??
        0;
  }

  Future<void> _checkExpiredPauses() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = await db.query(
      'paused_contacts',
      where: 'pause_until < ? AND auto_resume = 1',
      whereArgs: [now],
    );
    for (final pause in expired) {
      await unpauseContact(pause['contact_id'] as String);
    }
  }

  Future<void> _refreshList() async {
    _pausedContacts = await getPausedContacts();
    notifyListeners();
  }

  void _startPauseChecker() {
    _checkerTimer?.cancel();
    _checkerTimer = Timer.periodic(const Duration(minutes: 30), (_) => _checkExpiredPauses());
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _checkerTimer?.cancel();
    super.dispose();
  }
}
