// lib/main.dart
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:provider/provider.dart';

import 'database/database_helper.dart';
import 'sync/sync_queue.dart';
import 'sync/background_sync.dart';
import 'services/pause_chat_service.dart';
import 'services/warung_service.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi WorkManager untuk background sync
  await Workmanager().initialize(
    waroBackgroundSyncDispatcher,
    isInDebugMode: false,
  );

  // Register periodic background tasks
  await Workmanager().registerPeriodicTask(
    'waro_sync_task',
    'waroBackgroundSync',
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
    ),
  );

  await Workmanager().registerPeriodicTask(
    'waro_expire_warungs',
    'waroExpireWarungs',
    frequency: const Duration(minutes: 30),
  );

  // Inisialisasi database lokal
  await DatabaseHelper.instance.initDatabase();

  // Inisialisasi services
  SyncQueueManager().init();
  PauseChatService().init();
  WarungService().init();

  runApp(const WaroApp());
}

class WaroApp extends StatelessWidget {
  const WaroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncQueueManager()),
        ChangeNotifierProvider(create: (_) => WarungService()),
      ],
      child: MaterialApp(
        title: 'WARO - Warung Obrolan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2D7A4F),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F5F0),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
            backgroundColor: Color(0xFF2D7A4F),
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D7A4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2D7A4F),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
