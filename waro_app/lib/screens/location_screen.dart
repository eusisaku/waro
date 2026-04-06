// lib/screens/location_screen.dart
import 'package:flutter/material.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final String _myKecamatan = 'Kec. Klojen';
  final String _myKota = 'Malang';
  String _nextUpdate = '4 jam lagi';
  final List<int> _updateHours = [6, 12, 18]; // 3x sehari default

  // Teman sekitar (dummy data)
  final List<Map<String, dynamic>> _nearbyFriends = [
    {'name': 'Andi', 'kecamatan': 'Kec. Klojen', 'updatedAgo': '2 jam lalu', 'known': true},
    {'name': 'Sari', 'kecamatan': 'Kec. Klojen', 'updatedAgo': '5 jam lalu', 'known': true},
    {'name': 'Anonim', 'kecamatan': 'Kec. Klojen', 'updatedAgo': '1 jam lalu', 'known': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚶 Jalan-Jalan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showPrivacyInfo,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Lokasiku sekarang
          _buildLocationCard(),
          const SizedBox(height: 16),
          // Update schedule
          _buildUpdateScheduleCard(),
          const SizedBox(height: 16),
          // Teman di sekitar
          _buildNearbyFriends(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.location_on, color: Color(0xFF2D7A4F)),
              SizedBox(width: 8),
              Text('📍 Lokasimu Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            // Peta sederhana (blok kecamatan)
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2D7A4F).withOpacity(0.3)),
              ),
              child: Stack(
                children: [
                  // Grid peta sederhana
                  Positioned.fill(
                    child: CustomPaint(painter: _SimpleMapPainter()),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D7A4F),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_myKecamatan, $_myKota',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('📍', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                const Text('Lokasi exact tidak pernah dikirim', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Text('⏱ Update: $_nextUpdate', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateScheduleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🕐 Jadwal Update Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _ScheduleOption(
              label: '3x sehari (hemat baterai)',
              subtitle: 'Pagi, Siang, Malam',
              isSelected: true,
              onTap: () {},
            ),
            _ScheduleOption(
              label: '6x sehari',
              subtitle: 'Setiap 4 jam',
              isSelected: false,
              onTap: () {},
            ),
            _ScheduleOption(
              label: 'Manual saja',
              subtitle: 'Update hanya saat kamu mau',
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ..._updateHours.map((h) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text('${h.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(0xFF2D7A4F).withOpacity(0.1),
                        labelStyle: const TextStyle(color: Color(0xFF2D7A4F)),
                      ),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyFriends() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('👥 Teman di Sekitar Kecamatan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ..._nearbyFriends.map(_buildFriendTile),
      ],
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    final isKnown = friend['known'] as bool;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isKnown
              ? const Color(0xFF2D7A4F).withOpacity(0.15)
              : Colors.grey[200],
          child: Icon(
            Icons.person,
            color: isKnown ? const Color(0xFF2D7A4F) : Colors.grey,
          ),
        ),
        title: Text(isKnown ? friend['name'] : '👤 Orang tidak dikenal',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${friend['kecamatan']} • ${friend['updatedAgo']}',
            style: const TextStyle(fontSize: 12)),
        trailing: isKnown
            ? TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Chat', style: TextStyle(fontSize: 12)),
              )
            : TextButton.icon(
                onPressed: _showAnonymousGreet,
                icon: const Icon(Icons.waving_hand, size: 16),
                label: const Text('Sapa', style: TextStyle(fontSize: 12)),
              ),
      ),
    );
  }

  void _showAnonymousGreet() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sapa Anonim'),
        content: const Text(
          'Kamu akan mengirim "Halo" ke orang ini tanpa melihat identitasnya dulu.\n\nJika mereka membalas, kalian bisa saling kenalan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('👋 Sapaan anonim terkirim!')),
              );
            },
            child: const Text('Kirim Halo'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🔒 Privasi Lokasi WARO'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Lokasi hanya dibagikan sebagai nama kecamatan'),
            SizedBox(height: 8),
            Text('✅ Update maksimal 3x sehari (bukan real-time)'),
            SizedBox(height: 8),
            Text('✅ Koordinat GPS tidak pernah dikirim ke server'),
            SizedBox(height: 8),
            Text('✅ Bisa matikan kapan saja di pengaturan'),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti')),
        ],
      ),
    );
  }
}

class _ScheduleOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScheduleOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D7A4F).withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D7A4F) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF2D7A4F) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2D7A4F).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final step = size.width / 6;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
