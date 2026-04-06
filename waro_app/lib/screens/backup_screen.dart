// lib/screens/backup_screen.dart
import 'package:flutter/material.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isSignedIn = false;
  bool _isBackingUp = false;
  bool _autoBackupEnabled = true;
  double _progress = 0;
  String _status = '';

  // Dummy backup list
  final List<Map<String, dynamic>> _backups = [
    {'date': '5/4/2026 02:00', 'size': '1.2 MB', 'messages': 234, 'contacts': 12},
    {'date': '4/4/2026 02:00', 'size': '980 KB', 'messages': 210, 'contacts': 12},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('💾 Backup & Restore')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Google Drive card
                _buildGoogleDriveCard(),
                const SizedBox(height: 16),
                // Auto backup
                _buildAutoBackupCard(),
                const SizedBox(height: 16),
                // Manual backup
                if (_isSignedIn) _buildBackupButton(),
                const SizedBox(height: 16),
                // Daftar backup
                if (_isSignedIn) _buildBackupList(),
                const SizedBox(height: 80),
              ],
            ),
          ),
          // Progress overlay
          if (_isBackingUp) _buildProgressOverlay(),
        ],
      ),
    );
  }

  Widget _buildGoogleDriveCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _isSignedIn ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                color: _isSignedIn ? Colors.green[700] : Colors.grey[600],
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSignedIn ? 'Terhubung ke Google Drive' : 'Belum terhubung',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    _isSignedIn
                        ? 'Backup tersimpan di akun Google kamu'
                        : 'Login untuk mengaktifkan backup',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isSignedIn ? _signOut : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSignedIn ? Colors.red[400] : const Color(0xFF2D7A4F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(_isSignedIn ? 'Keluar' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFF2D7A4F), size: 28),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backup Otomatis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Setiap hari jam 02:00 (saat HP tidak dipakai)',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Switch(
              value: _autoBackupEnabled,
              onChanged: (v) => setState(() => _autoBackupEnabled = v),
              activeColor: const Color(0xFF2D7A4F),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isBackingUp ? null : _doBackup,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Backup Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBackupList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📦 Riwayat Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ..._backups.map(_buildBackupCard),
      ],
    );
  }

  Widget _buildBackupCard(Map<String, dynamic> backup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.backup, color: Colors.blue[700], size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(backup['date'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    '${backup['size']} • ${backup['messages']} pesan • ${backup['contacts']} kontak',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restore') _showRestoreDialog(backup);
                if (value == 'delete') _showDeleteDialog(backup);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'restore', child: Row(children: [Icon(Icons.restore, size: 16, color: Colors.orange), SizedBox(width: 8), Text('Restore')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Hapus')])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: _progress > 0 ? _progress : null, color: const Color(0xFF2D7A4F)),
                const SizedBox(height: 16),
                Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_progress > 0)
                  Text('${(_progress * 100).round()}%', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _signIn() {
    // Google Sign In implementation
    setState(() => _isSignedIn = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Berhasil terhubung ke Google Drive'), backgroundColor: Colors.green),
    );
  }

  void _signOut() {
    setState(() { _isSignedIn = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Keluar dari Google Drive'), backgroundColor: Colors.orange),
    );
  }

  Future<void> _doBackup() async {
    setState(() { _isBackingUp = true; _status = 'Mempersiapkan data...'; _progress = 0.1; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _status = 'Mengenkripsi data...'; _progress = 0.4; });
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() { _status = 'Upload ke Google Drive...'; _progress = 0.7; });
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _status = 'Selesai!'; _progress = 1.0; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _isBackingUp = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Backup berhasil!'), backgroundColor: Colors.green),
      );
    }
  }

  void _showRestoreDialog(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup dari: ${backup['date']}'),
            Text('Ukuran: ${backup['size']}'),
            const SizedBox(height: 12),
            const Text('⚠️ Data saat ini akan digantikan dengan data backup.', style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _doRestore(backup); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Backup?'),
        content: Text('Backup dari ${backup['date']} akan dihapus dari Google Drive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _backups.remove(backup));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup dihapus')));
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _doRestore(Map<String, dynamic> backup) async {
    setState(() { _isBackingUp = true; _status = 'Mengambil file backup...'; _progress = 0.2; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _status = 'Mendekripsi data...'; _progress = 0.5; });
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() { _status = 'Merestore data...'; _progress = 0.8; });
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _status = 'Selesai!'; _progress = 1.0; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _isBackingUp = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Restore berhasil!'), backgroundColor: Colors.green),
      );
    }
  }
}
