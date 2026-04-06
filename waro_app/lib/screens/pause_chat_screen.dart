// lib/screens/pause_chat_screen.dart
import 'package:flutter/material.dart';
import '../services/pause_chat_service.dart';

class PauseChatScreen extends StatefulWidget {
  final String contactId;
  final String contactName;

  const PauseChatScreen({super.key, required this.contactId, required this.contactName});

  @override
  State<PauseChatScreen> createState() => _PauseChatScreenState();
}

class _PauseChatScreenState extends State<PauseChatScreen> {
  int _selectedDays = 1;
  PauseReason _selectedReason = PauseReason.digitalDetox;
  final _customController = TextEditingController();
  bool _isLoading = false;

  final _service = PauseChatService();

  final _dayOptions = [1, 2, 3, 5, 7];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⏸ Pause Chat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pause chat dengan ${widget.contactName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '${widget.contactName} akan tahu kamu sedang istirahat. Pesan mereka akan disimpan & dikirim setelah pause selesai.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Durasi pause
            const Text('Durasi Pause', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _dayOptions.map((d) => GestureDetector(
                onTap: () => setState(() => _selectedDays = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 58,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _selectedDays == d ? const Color(0xFF2D7A4F) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedDays == d ? const Color(0xFF2D7A4F) : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$d',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _selectedDays == d ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      Text(
                        'hari',
                        style: TextStyle(
                          fontSize: 11,
                          color: _selectedDays == d ? Colors.white70 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Sampai: ${_getPauseUntilText()}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),

            // Alasan pause
            const Text('Alasan Pause', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...PauseReason.values.map((r) => _ReasonOption(
              reason: r,
              isSelected: _selectedReason == r,
              onTap: () => setState(() => _selectedReason = r),
            )),

            if (_selectedReason == PauseReason.custom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customController,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Tulis alasan kamu...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Info transparan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_outlined, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alasan dan durasi akan diketahui ${widget.contactName}. Ini fitur transparan, bukan blokir.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tombol
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _doPause,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                icon: const Icon(Icons.pause_circle),
                label: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Pause $_selectedDays hari',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPauseUntilText() {
    final until = DateTime.now().add(Duration(days: _selectedDays));
    return '${until.day}/${until.month}/${until.year} pukul ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _doPause() async {
    if (_selectedReason == PauseReason.custom && _customController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis alasan pausenya'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.pauseContact(
        contactId: widget.contactId,
        contactName: widget.contactName,
        durationDays: _selectedDays,
        reason: _selectedReason,
        customReason: _selectedReason == PauseReason.custom ? _customController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏸ Chat dengan ${widget.contactName} dipause $_selectedDays hari'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
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
    _customController.dispose();
    super.dispose();
  }
}

class _ReasonOption extends StatelessWidget {
  final PauseReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonOption({required this.reason, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Colors.orange : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reason.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      )),
                  Text(reason.description,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
