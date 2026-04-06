// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/pause_chat_service.dart';
import 'pause_chat_screen.dart';
import 'backup_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏪 Warungku')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          _buildProfileCard(context),
          const SizedBox(height: 16),
          // Menu pengaturan
          _buildSection('⚙️ Pengaturan', [
            _MenuItem(icon: Icons.pause_circle_outline, title: 'Kontak yang Dipause', subtitle: kIsWeb ? '1 kontak' : '0 kontak', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PausedContactsListScreen()))),
            _MenuItem(icon: Icons.notifications_outlined, title: 'Notifikasi', subtitle: 'Pagi & Malam saja', onTap: () {}),
            _MenuItem(icon: Icons.location_on_outlined, title: 'Pengaturan Lokasi', subtitle: 'Kecamatan (Privat)', onTap: () {}),
          ]),
          const SizedBox(height: 8),
          _buildSection('📦 Riwayat Warung', [
            _MenuItem(icon: Icons.history, title: 'Kopi Kenangan Kemarin', subtitle: 'Bubar 2 hari lalu', onTap: () {}),
            _MenuItem(icon: Icons.history, title: 'Mabar ML Waro', subtitle: 'Bubar 5 hari lalu', onTap: () {}),
          ]),
          const SizedBox(height: 8),
          _buildSection('💾 Data & Privasi', [
            _MenuItem(icon: Icons.backup_outlined, title: 'Backup ke File', subtitle: 'Simpan ke Memori HP', onTap: () {}),
            _MenuItem(icon: Icons.delete_outline, title: 'Hapus Cache', subtitle: 'Bebaskan ruang penyimpanan', onTap: () {}),
          ]),
          const SizedBox(height: 8),
          _buildSection('💰 Monetisasi', [
            _MenuItem(icon: Icons.bolt_outlined, title: 'Beli Pulsa Chat', subtitle: 'Mulai Rp5.000', onTap: () {}),
            _MenuItem(icon: Icons.audiotrack_outlined, title: 'Stiker Suara Lokal', subtitle: 'Paket Rp2.000', onTap: () {}),
            _MenuItem(icon: Icons.star_outline, title: 'Tentang WARO', onTap: () => _showAbout(context)),
          ]),
          const SizedBox(height: 24),
          // Versi
          Center(
            child: Text(
              'WARO v1.0.0\nMade with ☕ for Indonesia',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D7A4F), Color(0xFF4CAF80)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Budi Waro 🏠', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Bio: Santai saja di Warung...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on, size: 13, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Kec. Klojen, Malang', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF2D7A4F)),
              onPressed: () => _showEditProfile(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Identitas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Nama Lengkap', hintText: 'Budi Waro')),
            const SizedBox(height: 12),
            const TextField(maxLines: 2, decoration: InputDecoration(labelText: 'Bio / Status', hintText: 'Lagi ngopi...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Simpan')),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(e.value.icon, color: const Color(0xFF2D7A4F), size: 22),
                    title: Text(e.value.title, style: const TextStyle(fontSize: 14)),
                    subtitle: e.value.subtitle != null ? Text(e.value.subtitle!, style: const TextStyle(fontSize: 11)) : null,
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: e.value.onTap,
                    dense: true,
                  ),
                  if (!isLast) const Divider(height: 0, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🏠 Tentang WARO'),
        content: const Text(
          'WARO adalah aplikasi chat yang sengaja lambat.\n\n'
          'Fitur unik:\n'
          '• Pause Chat tanpa blokir\n'
          '• Warung Virtual 24 jam\n'
          '• Pulsa Chat harian\n'
          '• Lokasi privat (level kecamatan)\n'
          '• Suara Lingkungan\n\n'
          'Offline-first. Hemat kuota. Untuk Indonesia.',
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, this.subtitle, required this.onTap});
}

// ===== PAUSED CONTACTS LIST =====

class PausedContactsListScreen extends StatefulWidget {
  const PausedContactsListScreen({super.key});

  @override
  State<PausedContactsListScreen> createState() => _PausedContactsListScreenState();
}

class _PausedContactsListScreenState extends State<PausedContactsListScreen> {
  List<PausedContact> _paused = [];
  bool _isLoading = true;

  final _service = PauseChatService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (kIsWeb) {
      setState(() {
        _paused = [
          PausedContact(
            contactId: 'mock_1',
            contactName: 'Andi (Melihatmu)',
            reason: PauseReason.focus,
            pausedAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(hours: 4)),
            pendingMessagesCount: 3,
          ),
        ];
        _isLoading = false;
      });
      return;
    }
    try {
      final list = await _service.getPausedContacts();
      setState(() { _paused = list; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading paused: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⏸ Kontak Dipause')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paused.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Tidak ada chat yang dipause', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _paused.length,
                  itemBuilder: (_, i) => _buildPausedCard(_paused[i]),
                ),
    );
  }

  Widget _buildPausedCard(PausedContact p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.pause_circle, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(p.contactName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Text(p.formattedRemaining, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
            const SizedBox(height: 4),
            Text(p.reason.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (p.pendingMessagesCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text('${p.pendingMessagesCount} pesan tertunda', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.orange[50],
                  avatar: const Icon(Icons.schedule, size: 14, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _service.unpauseContact(p.contactId);
                    await _load();
                  },
                  child: const Text('Akhiri Pause'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
