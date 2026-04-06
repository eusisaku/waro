// lib/services/warung_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';

class Warung {
  final String warungId;
  final String name;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int maxMembers;
  int currentMembers;
  bool isActive;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  Warung({
    required this.warungId,
    required this.name,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.expiresAt,
    required this.maxMembers,
    required this.currentMembers,
    required this.isActive,
    this.lastMessage,
    this.lastMessageAt,
  });

  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAlmostExpired => !isExpired && timeRemaining.inHours < 5;

  double get progressPercent {
    if (isExpired) return 1.0;
    final total = expiresAt.difference(createdAt).inSeconds;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get formattedTimeRemaining {
    if (isExpired) return 'Sudah bubar';
    final r = timeRemaining;
    if (r.inHours > 0) return '${r.inHours} jam ${r.inMinutes % 60} mnt lagi';
    if (r.inMinutes > 0) return '${r.inMinutes} menit lagi';
    return '${r.inSeconds} detik lagi';
  }

  factory Warung.fromMap(Map<String, dynamic> map) => Warung(
        warungId: map['warung_id'],
        name: map['name'],
        createdBy: map['created_by'],
        createdByName: map['created_by_name'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at']),
        maxMembers: map['max_members'] ?? 5,
        currentMembers: map['current_members'] ?? 1,
        isActive: (map['is_active'] as int) == 1,
        lastMessage: map['last_message'],
        lastMessageAt: map['last_message_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_message_at'])
            : null,
      );

  Map<String, dynamic> toMap() => {
        'warung_id': warungId,
        'name': name,
        'created_by': createdBy,
        'created_by_name': createdByName,
        'created_at': createdAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'max_members': maxMembers,
        'current_members': currentMembers,
        'is_active': isActive ? 1 : 0,
      };
}

class WarungMember {
  final String warungId;
  final String userId;
  final String userName;
  final DateTime joinedAt;

  WarungMember({
    required this.warungId,
    required this.userId,
    required this.userName,
    required this.joinedAt,
  });

  factory WarungMember.fromMap(Map<String, dynamic> map) => WarungMember(
        warungId: map['warung_id'],
        userId: map['user_id'],
        userName: map['user_name'],
        joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joined_at']),
      );
}

class WarungService extends ChangeNotifier {
  static final WarungService _instance = WarungService._internal();
  factory WarungService() => _instance;
  WarungService._internal();

  DatabaseHelper get _db => DatabaseHelper.instance;
  Timer? _expiryTimer;

  List<Warung> _activeWarungs = [];
  List<Warung> _expiredWarungs = [];

  List<Warung> get activeWarungs => _activeWarungs;
  List<Warung> get expiredWarungs => _expiredWarungs;

  void init() {
    if (kIsWeb) return;
    _startExpiryChecker();
    checkAndExpireWarungs();
  }

  // ===== CREATE =====

  Future<Warung> createWarung({
    required String name,
    required String createdBy,
    required String createdByName,
    int maxMembers = AppConstants.warungMaxMembers,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: AppConstants.warungDurationHours));
    final warungId = 'wr_${now.millisecondsSinceEpoch}';

    final warung = Warung(
      warungId: warungId,
      name: name,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: now,
      expiresAt: expiresAt,
      maxMembers: maxMembers,
      currentMembers: 1,
      isActive: true,
    );

    if (kIsWeb) {
      _webWarungs.insert(0, warung);
      await loadWarungs(createdBy);
      return warung;
    }

    final db = await _db.database;

    await db.insert('warungs', warung.toMap());

    // Tambah creator sebagai member
    await db.insert('warung_members', {
      'warung_id': warungId,
      'user_id': createdBy,
      'user_name': createdByName,
      'joined_at': now.millisecondsSinceEpoch,
    });

    // Pesan sistem pembuka
    await _sendSystemMessage(
      warungId: warungId,
      message: '🏠 Warung "$name" dibuka oleh $createdByName. Warung akan bubar otomatis dalam 24 jam.',
    );

    await loadWarungs(createdBy);
    debugPrint('🏠 Warung baru: $name ($warungId)');
    return warung;
  }

  // ===== JOIN =====

  Future<bool> joinWarung({
    required String warungId,
    required String userId,
    required String userName,
  }) async {
    final db = await _db.database;
    final warung = await getWarung(warungId);

    if (warung == null || !warung.isActive || warung.isExpired) {
      throw Exception('Warung tidak aktif atau sudah bubar');
    }

    final existing = await db.query(
      'warung_members',
      where: 'warung_id = ? AND user_id = ?',
      whereArgs: [warungId, userId],
    );
    if (existing.isNotEmpty) return false;

    if (warung.currentMembers >= warung.maxMembers) {
      throw Exception('Warung sudah penuh (maks ${warung.maxMembers} orang)');
    }

    await db.insert('warung_members', {
      'warung_id': warungId,
      'user_id': userId,
      'user_name': userName,
      'joined_at': DateTime.now().millisecondsSinceEpoch,
    });

    await db.update(
      'warungs',
      {'current_members': warung.currentMembers + 1},
      where: 'warung_id = ?',
      whereArgs: [warungId],
    );

    await _sendSystemMessage(warungId: warungId, message: '👋 $userName bergabung ke warung!');
    return true;
  }

  // ===== LEAVE =====

  Future<void> leaveWarung({
    required String warungId,
    required String userId,
    required String userName,
  }) async {
    final db = await _db.database;
    final warung = await getWarung(warungId);
    if (warung == null) return;

    await db.delete(
      'warung_members',
      where: 'warung_id = ? AND user_id = ?',
      whereArgs: [warungId, userId],
    );

    final newCount = warung.currentMembers - 1;
    await db.update(
      'warungs',
      {'current_members': newCount},
      where: 'warung_id = ?',
      whereArgs: [warungId],
    );

    await _sendSystemMessage(warungId: warungId, message: '🚪 $userName meninggalkan warung.');

    if (newCount <= 0) {
      await _expireWarung(warungId, reason: 'Tidak ada anggota');
    }
  }

  // ===== GET =====

  Future<List<Warung>> getActiveWarungs(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT w.*,
        (SELECT content FROM messages WHERE warung_id = w.warung_id ORDER BY sent_at DESC LIMIT 1) as last_message,
        (SELECT sent_at FROM messages WHERE warung_id = w.warung_id ORDER BY sent_at DESC LIMIT 1) as last_message_at
      FROM warungs w
      INNER JOIN warung_members wm ON w.warung_id = wm.warung_id
      WHERE wm.user_id = ? AND w.is_active = 1 AND w.expires_at > ?
      ORDER BY w.created_at DESC
    ''', [userId, DateTime.now().millisecondsSinceEpoch]);
    return result.map(Warung.fromMap).toList();
  }

  Future<List<Warung>> getExpiredWarungs(String userId, {int limit = 20}) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT w.* FROM warungs w
      INNER JOIN warung_members wm ON w.warung_id = wm.warung_id
      WHERE wm.user_id = ? AND (w.is_active = 0 OR w.expires_at < ?)
      ORDER BY w.expires_at DESC LIMIT ?
    ''', [userId, DateTime.now().millisecondsSinceEpoch, limit]);
    return result.map(Warung.fromMap).toList();
  }

  Future<Warung?> getWarung(String warungId) async {
    final db = await _db.database;
    final result = await db.query('warungs', where: 'warung_id = ?', whereArgs: [warungId]);
    if (result.isEmpty) return null;
    return Warung.fromMap(result.first);
  }

  Future<List<WarungMember>> getWarungMembers(String warungId) async {
    final db = await _db.database;
    final result = await db.query(
      'warung_members',
      where: 'warung_id = ?',
      whereArgs: [warungId],
      orderBy: 'joined_at ASC',
    );
    return result.map(WarungMember.fromMap).toList();
  }

  List<Warung> _webWarungs = []; // Temporary storage for web testing

  Future<void> loadWarungs(String userId) async {
    if (kIsWeb) {
      // Mock data awal untuk web
      if (_webWarungs.isEmpty) {
        _webWarungs = [
          Warung(
            warungId: 'wr_mock_1',
            name: 'Pojok Digital Detox',
            createdBy: 'user_1',
            createdByName: 'Andi',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
            expiresAt: DateTime.now().add(const Duration(hours: 20)),
            maxMembers: 5,
            currentMembers: 3,
            isActive: true,
            lastMessage: 'Ayo ngopi tenang di sini ☕',
          ),
          Warung(
            warungId: 'wr_mock_2',
            name: 'Waro Malam Jumatan',
            createdBy: 'user_2',
            createdByName: 'Budi',
            createdAt: DateTime.now().subtract(const Duration(hours: 22)),
            expiresAt: DateTime.now().add(const Duration(hours: 2)),
            maxMembers: 5,
            currentMembers: 5,
            isActive: true,
            lastMessage: '⚠️ Segera bubar guys!',
          ),
        ];
      }
      _activeWarungs = _webWarungs.where((w) => !w.isExpired).toList();
      _expiredWarungs = _webWarungs.where((w) => w.isExpired).toList();
      notifyListeners();
      return;
    }
    _activeWarungs = await getActiveWarungs(userId);
    _expiredWarungs = await getExpiredWarungs(userId);
    notifyListeners();
  }

  // ===== EXTEND (Premium) =====

  Future<void> extendWarung(String warungId, {int additionalHours = 24}) async {
    final db = await _db.database;
    final warung = await getWarung(warungId);
    if (warung == null || !warung.isActive) return;

    final newExpiry = warung.expiresAt.add(Duration(hours: additionalHours));
    await db.update(
      'warungs',
      {'expires_at': newExpiry.millisecondsSinceEpoch},
      where: 'warung_id = ?',
      whereArgs: [warungId],
    );
    await _sendSystemMessage(warungId: warungId, message: '⏰ Warung diperpanjang $additionalHours jam!');
  }

  // ===== EXPIRE =====

  Future<void> checkAndExpireWarungs() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = await db.query(
      'warungs',
      where: 'is_active = 1 AND expires_at < ?',
      whereArgs: [now],
    );
    for (final w in expired) {
      await _expireWarung(w['warung_id'] as String, reason: 'Waktu 24 jam habis');
    }
  }

  Future<void> _expireWarung(String warungId, {required String reason}) async {
    final db = await _db.database;
    final warung = await getWarung(warungId);
    if (warung == null) return;

    await db.update('warungs', {'is_active': 0}, where: 'warung_id = ?', whereArgs: [warungId]);

    final members = await getWarungMembers(warungId);
    for (final member in members) {
      await _sendSystemMessage(
        warungId: warungId,
        recipientId: member.userId,
        message:
            '🏠 Warung "${warung.name}" telah bubar.\nAlasan: $reason\n\nTerima kasih sudah berkumpul! Buat warung baru kapan saja.',
      );
    }

    debugPrint('🏠 Warung ${warung.name} bubar: $reason');
    notifyListeners();
  }

  Future<void> cleanupOldWarungs() async {
    final db = await _db.database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: AppConstants.warungCleanupDays))
        .millisecondsSinceEpoch;
    final deleted = await db.delete(
      'warungs',
      where: 'is_active = 0 AND expires_at < ?',
      whereArgs: [cutoff],
    );
    if (deleted > 0) debugPrint('🧹 Cleanup $deleted warung lama');
  }

  // ===== HELPERS =====

  Future<void> _sendSystemMessage({
    required String warungId,
    required String message,
    String? recipientId,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (recipientId != null) {
      await db.insert('messages', {
        'message_id': 'sys_${now}_$warungId',
        'warung_id': warungId,
        'recipient_id': recipientId,
        'sender_id': 'system',
        'sender_name': 'Sistem WARO',
        'content': message,
        'message_type': 'system',
        'sent_at': now,
        'sync_status': 'synced',
      });
    } else {
      final members = await getWarungMembers(warungId);
      for (final member in members) {
        await db.insert('messages', {
          'message_id': 'sys_${now}_${member.userId}',
          'warung_id': warungId,
          'recipient_id': member.userId,
          'sender_id': 'system',
          'sender_name': 'Sistem WARO',
          'content': message,
          'message_type': 'system',
          'sent_at': now,
          'sync_status': 'synced',
        });
      }
    }
  }

  void _startExpiryChecker() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(minutes: 10), (_) => checkAndExpireWarungs());
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}
