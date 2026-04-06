// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/warung_service.dart';
import '../sync/sync_queue.dart';
import '../widgets/warung_card_widget.dart';
import '../widgets/sync_status_indicator.dart';
import 'chat_screen.dart';
import 'pulsa_screen.dart';
import 'location_screen.dart';
import 'profile_screen.dart';
import 'create_warung_screen.dart';

const String _currentUserId = 'me'; // Diganti dengan auth user
const String _currentUserName = 'Saya';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  final List<Widget> _tabs = const [
    _WarungTab(),
    ChatScreen(),
    PulsaScreen(),
    LocationScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WarungService>().loadWarungs(_currentUserId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedTab, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Warung'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Pulsa'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Jalan-Jalan'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Warungku'),
        ],
      ),
    );
  }
}

class _WarungTab extends StatelessWidget {
  const _WarungTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WARO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          const SyncStatusIndicator(),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<WarungService>(
        builder: (context, service, _) {
          return RefreshIndicator(
            onRefresh: () => service.loadWarungs(_currentUserId),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Header pulsa cepat
                _PulsaBanner(),

                // Warung Aktif
                if (service.activeWarungs.isNotEmpty) ...[
                  _SectionHeader(
                    title: '🏠 WARUNG AKTIF (${service.activeWarungs.length})',
                  ),
                  ...service.activeWarungs.map(
                    (w) => WarungCard(
                      warung: w,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatScreen(warungId: w.warungId)),
                      ),
                      onLeave: () => _showLeaveDialog(context, service, w),
                    ),
                  ),
                ],

                // Buat warung baru
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateWarungScreen(
                          userId: _currentUserId,
                          userName: _currentUserName,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Buat Warung Baru'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Color(0xFF2D7A4F)),
                      foregroundColor: const Color(0xFF2D7A4F),
                    ),
                  ),
                ),

                // Warung Bubar (Arsip)
                if (service.expiredWarungs.isNotEmpty) ...[
                  _SectionHeader(title: '📦 WARUNG SUDAH BUBAR'),
                  ...service.expiredWarungs.map(
                    (w) => WarungCard(warung: w, onTap: () {}, isArchive: true),
                  ),
                ],

                if (service.activeWarungs.isEmpty && service.expiredWarungs.isEmpty)
                  _EmptyWarungState(),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, WarungService service, Warung warung) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Warung?'),
        content: Text('Anda akan keluar dari "${warung.name}". Chat tersimpan di arsip.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await service.leaveWarung(
                warungId: warung.warungId,
                userId: _currentUserId,
                userName: _currentUserName,
              );
              await service.loadWarungs(_currentUserId);
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _PulsaBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D7A4F), Color(0xFF4CAF80)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚡ 20 pulsa tersisa hari ini',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Reset otomatis besok jam 00:00',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () {},
            child: const Text('Isi Pulsa'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyWarungState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(Icons.store_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Belum ada warung aktif',
              style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat warung baru dan ajak teman!\nWarung akan bubar otomatis setelah 24 jam.',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
