// lib/services/backup_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';

/// Status hasil operasi backup/restore
enum BackupStatus { success, failed, notFound, decryptError }

class BackupResult {
  final BackupStatus status;
  final String message;
  final String? filePath;
  const BackupResult({required this.status, required this.message, this.filePath});
}

/// [BackupService] — Enkripsi AES-256 + export/import seluruh data lokal.
/// Produksi: integrasikan dengan google_sign_in + googleapis untuk upload
/// ke Google Drive. Saat ini menggunakan direktori lokal sebagai target.
class BackupService {
  static const String _backupPrefix = 'waro_backup_';
  static const String _backupExtension = '.warobak';

  final DatabaseHelper _db;

  BackupService({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  // ====================================================================
  // 1. BUAT BACKUP
  // ====================================================================

  /// Buat backup terenkripsi dari seluruh database lokal.
  /// [passphrase] digunakan sebagai dasar key AES-256.
  Future<BackupResult> createBackup(String passphrase) async {
    try {
      // Kumpulkan semua data
      final data = await _exportAllData();
      final jsonStr = jsonEncode(data);

      // Enkripsi
      final encrypted = _encrypt(jsonStr, passphrase);

      // Simpan ke file
      final dir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$_backupPrefix$timestamp$_backupExtension';
      final filePath = path.join(dir.path, fileName);

      final file = File(filePath);
      await file.writeAsString(encrypted, flush: true);

      // Cleanup backup lama
      await _cleanupOldBackups(dir);

      return BackupResult(
        status: BackupStatus.success,
        message: 'Backup berhasil: $fileName',
        filePath: filePath,
      );
    } catch (e) {
      return BackupResult(
        status: BackupStatus.failed,
        message: 'Gagal membuat backup: $e',
      );
    }
  }

  // ====================================================================
  // 2. RESTORE BACKUP
  // ====================================================================

  /// Restore dari file backup terenkripsi.
  Future<BackupResult> restoreBackup(String filePath, String passphrase) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const BackupResult(status: BackupStatus.notFound, message: 'File backup tidak ditemukan');
      }

      final encrypted = await file.readAsString();

      // Dekripsi
      String jsonStr;
      try {
        jsonStr = _decrypt(encrypted, passphrase);
      } catch (_) {
        return const BackupResult(
          status: BackupStatus.decryptError,
          message: 'Passphrase salah atau file rusak',
        );
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Restore ke database
      await _importAllData(data);

      return const BackupResult(
        status: BackupStatus.success,
        message: 'Restore berhasil! Data telah dipulihkan.',
      );
    } catch (e) {
      return BackupResult(
        status: BackupStatus.failed,
        message: 'Gagal restore: $e',
      );
    }
  }

  // ====================================================================
  // 3. DAFTAR BACKUP
  // ====================================================================

  Future<List<BackupFileInfo>> listBackups() async {
    try {
      final dir = await _getBackupDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => path.basename(f.path).startsWith(_backupPrefix) &&
              f.path.endsWith(_backupExtension))
          .toList();

      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return files.map((f) {
        final stat = f.statSync();
        final name = path.basename(f.path);
        // Extract timestamp dari nama file
        final tsStr = name
            .replaceFirst(_backupPrefix, '')
            .replaceAll(_backupExtension, '');
        final ts = int.tryParse(tsStr);
        final date = ts != null
            ? DateTime.fromMillisecondsSinceEpoch(ts)
            : stat.modified;

        return BackupFileInfo(
          filePath: f.path,
          fileName: name,
          createdAt: date,
          sizeBytes: stat.size,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ====================================================================
  // 4. HAPUS BACKUP
  // ====================================================================

  Future<bool> deleteBackup(String filePath) async {
    try {
      await File(filePath).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ====================================================================
  // 5. AUTO-BACKUP (dipanggil dari WorkManager)
  // ====================================================================

  /// Backup otomatis dengan passphrase dari SharedPreferences / secure storage
  Future<BackupResult> autoBackup(String passphrase) async {
    if (passphrase.isEmpty) {
      return const BackupResult(
        status: BackupStatus.failed,
        message: 'Passphrase belum diatur. Buka Pengaturan > Backup untuk mengatur.',
      );
    }
    return createBackup(passphrase);
  }

  // ====================================================================
  // PRIVATE — Export data ke Map
  // ====================================================================

  Future<Map<String, dynamic>> _exportAllData() async {
    final db = await _db.database;

    Future<List<Map>> table(String name) => db.query(name);

    return {
      'version': AppConstants.appVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'users': await table('users'),
      'contacts': await table('contacts'),
      'warungs': await table('warungs'),
      'warung_members': await table('warung_members'),
      'messages': await table('messages'),
      'pulsa_transactions': await table('pulsa_transactions'),
      'location_history': await table('location_history'),
      'paused_contacts': await table('paused_contacts'),
      'pending_messages': await table('pending_messages'),
      'sync_queue': await table('sync_queue'),
    };
  }

  // ====================================================================
  // PRIVATE — Import data dari Map
  // ====================================================================

  Future<void> _importAllData(Map<String, dynamic> data) async {
    final db = await _db.database;

    final tables = [
      'sync_queue', 'pending_messages', 'paused_contacts', 'location_history',
      'pulsa_transactions', 'messages', 'warung_members', 'warungs',
      'contacts', 'users',
    ];

    await db.transaction((txn) async {
      // Hapus data lama (urutan terbalik untuk FK)
      for (final t in tables) {
        await txn.delete(t);
      }

      // Insert data baru
      for (final t in tables.reversed) {
        final rows = (data[t] as List<dynamic>? ?? []);
        for (final row in rows) {
          await txn.insert(t, Map<String, dynamic>.from(row as Map));
        }
      }
    });
  }

  // ====================================================================
  // PRIVATE — Enkripsi / Dekripsi AES-256
  // ====================================================================

  String _encrypt(String plainText, String passphrase) {
    final key = _deriveKey(passphrase);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Format: base64(IV) + ':' + base64(ciphertext)
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  String _decrypt(String encryptedStr, String passphrase) {
    final parts = encryptedStr.split(':');
    if (parts.length != 2) throw const FormatException('Format backup tidak valid');

    final key = _deriveKey(passphrase);
    final iv = enc.IV(base64.decode(parts[0]));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  enc.Key _deriveKey(String passphrase) {
    // PBKDF2-like: SHA-256 dari passphrase + salt tetap (production: gunakan salt acak yang disimpan)
    const salt = 'WARO_SALT_2024';
    final bytes = utf8.encode(passphrase + salt);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  // ====================================================================
  // PRIVATE — Direktori backup lokal
  // ====================================================================

  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(appDir.path, 'waro_backups'));
    if (!backupDir.existsSync()) await backupDir.create(recursive: true);
    return backupDir;
  }

  /// Hapus backup lama jika melebihi maxLocalBackups
  Future<void> _cleanupOldBackups(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(_backupExtension))
        .toList();

    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    if (files.length > AppConstants.maxLocalBackups) {
      final toDelete = files.sublist(AppConstants.maxLocalBackups);
      for (final f in toDelete) {
        await f.delete();
      }
    }
  }
}

// ====================================================================
// Model info backup
// ====================================================================

class BackupFileInfo {
  final String filePath;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupFileInfo({
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}


