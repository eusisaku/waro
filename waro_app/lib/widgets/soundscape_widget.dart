// lib/widgets/soundscape_widget.dart
import 'package:flutter/material.dart';
import '../services/sound_recorder_service.dart';

class SoundscapeRecorderWidget extends StatefulWidget {
  final Function(String filePath) onSoundscapeRecorded;

  const SoundscapeRecorderWidget({super.key, required this.onSoundscapeRecorded});

  @override
  State<SoundscapeRecorderWidget> createState() => _SoundscapeRecorderWidgetState();
}

class _SoundscapeRecorderWidgetState extends State<SoundscapeRecorderWidget>
    with SingleTickerProviderStateMixin {
  final _svc = SoundRecorderService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _svc.init();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.graphic_eq, color: Color(0xFF2D7A4F)),
                  const SizedBox(width: 8),
                  const Text('Suara Lingkungan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  if (_svc.state == RecordingState.idle && !_svc.hasRecording)
                    Text('maks 10 detik', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (_svc.state == RecordingState.recording)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Konten sesuai state
              if (_svc.state == RecordingState.recording)
                _buildRecordingView()
              else if (_svc.hasRecording && _svc.state != RecordingState.recording)
                _buildPreviewView()
              else
                _buildIdleView(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIdleView() {
    return Column(
      children: [
        Text(
          '🎤 Tahan tombol untuk merekam suara sekitar',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTapDown: (_) => _startRecord(),
          onTapCancel: () => _stopRecord(),
          onTapUp: (_) => _stopRecord(),
          child: AnimatedScale(
            scale: _svc.state == RecordingState.recording ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF4CAF80), Color(0xFF2D7A4F)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Tahan untuk rekam', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildRecordingView() {
    return Column(
      children: [
        // Timer
        Text(
          _svc.formattedDuration,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 8),
        // Progress
        LinearProgressIndicator(
          value: _svc.recordingProgress,
          backgroundColor: Colors.grey[200],
          color: Colors.red[400],
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 16),
        // Waveform animasi
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              12,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: (8 + (i % 5) * 8).toDouble() * (_pulseAnim.value - 0.5 + 0.5),
                decoration: BoxDecoration(
                  color: Colors.red[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Tombol stop
        ElevatedButton.icon(
          onPressed: _stopRecord,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
          icon: const Icon(Icons.stop),
          label: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _buildPreviewView() {
    return Column(
      children: [
        // Sound wave preview (static)
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2D7A4F).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              20,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: (6 + (i * 17 % 30)).toDouble(),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7A4F).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Hapus
            TextButton.icon(
              onPressed: () async {
                await _svc.deleteRecording(_svc.currentRecordingPath!);
                _svc.reset();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
            // Preview
            OutlinedButton.icon(
              onPressed: () {
                if (_svc.state == RecordingState.playing) {
                  _svc.stopPreview();
                } else {
                  _svc.playPreview(_svc.currentRecordingPath!);
                }
              },
              icon: Icon(_svc.state == RecordingState.playing ? Icons.stop : Icons.play_arrow),
              label: Text(_svc.state == RecordingState.playing ? 'Stop' : 'Preview'),
            ),
            // Kirim
            ElevatedButton.icon(
              onPressed: () => widget.onSoundscapeRecorded(_svc.currentRecordingPath!),
              icon: const Icon(Icons.send),
              label: const Text('Kirim'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startRecord() async {
    try {
      await _svc.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _stopRecord() async {
    try {
      await _svc.stopRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.orange));
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
