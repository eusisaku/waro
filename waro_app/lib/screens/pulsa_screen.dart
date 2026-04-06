// lib/screens/pulsa_screen.dart
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';

class PulsaScreen extends StatefulWidget {
  const PulsaScreen({super.key});

  @override
  State<PulsaScreen> createState() => _PulsaScreenState();
}

class _PulsaScreenState extends State<PulsaScreen> {
  int _balance = 0;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (kIsWeb) {
      setState(() {
        _balance = 20; // Default dummy balance for web
        _history = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final balanceResult = await db.query('pulsa_balance', where: 'id = 1');
      final historyResult = await db.query(
        'pulsa_transactions',
        orderBy: 'created_at DESC',
        limit: 30,
      );
      setState(() {
        _balance = balanceResult.isNotEmpty ? (balanceResult.first['balance'] as int? ?? 0) : 0;
        _history = historyResult;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading pulsa: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚡ Pulsa Chat')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Kartu saldo
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
                  // Minta pulsa
                  _buildRequestPulsaCard(),
                  const SizedBox(height: 16),
                  // Beli pulsa
                  _buildBuyPulsaCard(),
                  const SizedBox(height: 24),
                  // Riwayat
                  _buildHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    final percentage = (_balance / AppConstants.dailyPulsaAllotment).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D7A4F), Color(0xFF1B4D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF2D7A4F).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Icon(Icons.bolt, color: Colors.white, size: 48),
          const SizedBox(height: 8),
          Text(
            '$_balance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text('pulsa tersisa hari ini', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.white24,
              color: Colors.white,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '🔄 Reset otomatis besok jam 00:00',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPulsaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.send, color: Color(0xFF2D7A4F)),
              SizedBox(width: 8),
              Text('Minta Pulsa ke Teman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
            const Text('Pilih teman yang mau diminta pulsanya', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showContactPicker,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Pilih Kontak'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyPulsaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.shopping_cart_outlined, color: Color(0xFF2D7A4F)),
              SizedBox(width: 8),
              Text('Beli Pulsa Ekstra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            ...AppConstants.pulsaPrices.entries.map(
              (e) => _PulsaPackCard(pulsa: e.key, price: e.value),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const Text('Bayar pakai:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              children: [
                PaymentChip(label: 'QRIS'),
                PaymentChip(label: 'OVO'),
                PaymentChip(label: 'ShopeePay'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📊 Riwayat Pulsa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Belum ada riwayat', style: TextStyle(color: Colors.grey[400])),
            ),
          )
        else
          ..._history.map(_buildHistoryTile),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> tx) {
    final type = tx['type'] as String;
    final amount = tx['amount'] as int;
    final isIncome = amount > 0;

    final typeLabel = {
      'daily_allotment': 'Pulsa harian',
      'gift': 'Dari teman',
      'purchase': 'Pembelian',
      'request': 'Permintaan',
    }[type] ?? type;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
        child: Icon(
          isIncome ? Icons.add : Icons.remove,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
      title: Text(typeLabel),
      subtitle: Text(_formatDate(tx['created_at'])),
      trailing: Text(
        '${isIncome ? '+' : ''}$amount',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  void _showContactPicker() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur memilih kontak untuk minta pulsa')),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts as int);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _PulsaPackCard extends StatelessWidget {
  final int pulsa;
  final int price;
  const _PulsaPackCard({required this.pulsa, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Color(0xFF2D7A4F)),
          const SizedBox(width: 8),
          Text('$pulsa pulsa', style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('Rp${_formatPrice(price)}',
              style: const TextStyle(color: Color(0xFF2D7A4F), fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Beli'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int p) => p.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class PaymentChip extends StatelessWidget {
  final String label;
  const PaymentChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.grey[100],
    );
  }
}

SizedBox _buildSizedBox(double height) => SizedBox(height: height);
SizedBox sizedBox(double height) => SizedBox(height: height);
