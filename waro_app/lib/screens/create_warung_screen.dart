// lib/screens/create_warung_screen.dart
import 'package:flutter/material.dart';
import '../services/warung_service.dart';

class CreateWarungScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const CreateWarungScreen({super.key, required this.userId, required this.userName});

  @override
  State<CreateWarungScreen> createState() => _CreateWarungScreenState();
}

class _CreateWarungScreenState extends State<CreateWarungScreen> {
  final _nameController = TextEditingController();
  int _maxMembers = 5;
  bool _isLoading = false;

  final _service = WarungService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏠 Buat Warung Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ilustrasi atas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D7A4F), Color(0xFF4CAF80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Text('🏠', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 8),
                  Text(
                    'Warung Virtual — Nongkrong 24 Jam',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Setelah 24 jam, warung otomatis bubar.\nRiwayat chat tetap tersimpan.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nama warung
            const Text('Nama Warung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'Contoh: Warung Soto Kos Pak Hari',
                prefixIcon: const Icon(Icons.store_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Maks anggota
            const Text('Maksimal Anggota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [5, 7, 10].map((v) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _maxMembers = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 72,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _maxMembers == v ? const Color(0xFF2D7A4F) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _maxMembers == v ? const Color(0xFF2D7A4F) : Colors.grey[300]!,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$v orang',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _maxMembers == v ? Colors.white : Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warung akan otomatis bubar setelah 24 jam. Bisa diperpanjang +24 jam dengan Rp1.000.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tombol buat
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createWarung,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('🏠 Buat Warung',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createWarung() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama warung dulu'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final warung = await _service.createWarung(
        name: _nameController.text.trim(),
        createdBy: widget.userId,
        createdByName: widget.userName,
        maxMembers: _maxMembers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏠 Warung "${warung.name}" berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, warung);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
