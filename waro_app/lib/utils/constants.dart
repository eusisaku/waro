// lib/utils/constants.dart

class AppConstants {
  // App info
  static const String appName = 'WARO';
  static const String appVersion = '1.0.0';

  // Pulsa chat
  static const int dailyPulsaAllotment = 20;
  static const int maxPulsaPerDay = 100;

  // Warung
  static const int warungDurationHours = 24;
  static const int warungMaxMembers = 5;
  static const int warungCleanupDays = 30;

  // Soundscape
  static const int soundscapeMaxDurationSeconds = 10;
  static const int soundscapeMinDurationSeconds = 2;
  static const int soundscapeSampleRate = 22050;
  static const int soundscapeBitRate = 64000;

  // Sync
  static const int syncBatchSize = 20;
  static const int syncMaxRetry = 5;
  static const List<int> syncRetryDelaysSeconds = [30, 60, 120, 300, 600];

  // Pause
  static const int pauseMinDays = 1;
  static const int pauseMaxDays = 7;

  // Location update schedule (jam WIB)
  static const List<int> locationUpdateHours = [6, 12, 18];

  // API
  static const String apiBaseUrl = 'https://api.waro.id/v1';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Database
  static const String dbName = 'waro_local.db';
  static const int dbVersion = 1;

  // Backup
  static const int maxLocalBackups = 10;
  static const int autoBackupHour = 2; // 02:00 WIB

  // Monetisasi - harga pulsa
  static const Map<int, int> pulsaPrices = {
    10: 5000,
    25: 10000,
    60: 20000,
  };

  // Monetisasi - harga stiker
  static const int soundStickerPackPrice = 2000;

  // Monetisasi - perpanjang warung
  static const int warungExtendPrice = 1000;
}
