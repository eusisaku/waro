// lib/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception('Database SQLite tidak didukung di platform Web. Gunakan Android atau Windows.');
    }
    _database ??= await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    if (kIsWeb) throw Exception('Database Init tidak didukung di Web');

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }


  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        user_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone_number TEXT,
        avatar TEXT,
        created_at INTEGER,
        total_pulsa_received INTEGER DEFAULT 0,
        total_pulsa_given INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        contact_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone_number TEXT,
        avatar TEXT,
        last_seen INTEGER,
        kecamatan TEXT,
        is_paused INTEGER DEFAULT 0,
        pause_until INTEGER,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE warungs (
        warung_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_by TEXT NOT NULL,
        created_by_name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        max_members INTEGER DEFAULT 5,
        current_members INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        last_message TEXT,
        last_message_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE warung_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        warung_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        joined_at INTEGER NOT NULL,
        last_read_at INTEGER,
        FOREIGN KEY (warung_id) REFERENCES warungs(warung_id) ON DELETE CASCADE,
        UNIQUE(warung_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        message_id TEXT PRIMARY KEY,
        warung_id TEXT,
        recipient_id TEXT,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        message_type TEXT DEFAULT 'text',
        content TEXT,
        soundscape_url TEXT,
        soundscape_duration INTEGER,
        sent_at INTEGER,
        delivered_at INTEGER,
        is_read INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE pulsa_transactions (
        transaction_id TEXT PRIMARY KEY,
        from_user_id TEXT,
        to_user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        created_at INTEGER,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE pulsa_balance (
        id INTEGER PRIMARY KEY,
        balance INTEGER DEFAULT 20,
        last_reset_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE location_history (
        history_id INTEGER PRIMARY KEY AUTOINCREMENT,
        kecamatan TEXT NOT NULL,
        recorded_at INTEGER,
        source TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE paused_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id TEXT NOT NULL UNIQUE,
        contact_name TEXT NOT NULL,
        pause_until INTEGER NOT NULL,
        reason TEXT NOT NULL,
        custom_reason TEXT,
        auto_resume INTEGER DEFAULT 1,
        pending_messages_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        message TEXT NOT NULL,
        is_urgent INTEGER DEFAULT 0,
        sent_at INTEGER NOT NULL,
        is_read INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        created_at INTEGER,
        last_attempt_at INTEGER,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE failed_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_id INTEGER,
        operation TEXT,
        table_name TEXT,
        record_id TEXT,
        payload TEXT,
        error TEXT,
        failed_at INTEGER
      )
    ''');

    // Indexes untuk performa
    await db.execute('CREATE INDEX idx_messages_recipient ON messages(recipient_id)');
    await db.execute('CREATE INDEX idx_messages_warung ON messages(warung_id)');
    await db.execute('CREATE INDEX idx_messages_sent_at ON messages(sent_at)');
    await db.execute('CREATE INDEX idx_warungs_expires ON warungs(expires_at)');
    await db.execute('CREATE INDEX idx_warungs_active ON warungs(is_active)');
    await db.execute('CREATE INDEX idx_warung_members_user ON warung_members(user_id)');
    await db.execute('CREATE INDEX idx_paused_contacts_id ON paused_contacts(contact_id)');
    await db.execute('CREATE INDEX idx_pending_messages_contact ON pending_messages(contact_id)');
    await db.execute('CREATE INDEX idx_sync_queue_retry ON sync_queue(retry_count)');

    // Insert saldo pulsa awal
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('pulsa_balance', {
      'id': 1,
      'balance': AppConstants.dailyPulsaAllotment,
      'last_reset_at': now,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrasi future version disini
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
