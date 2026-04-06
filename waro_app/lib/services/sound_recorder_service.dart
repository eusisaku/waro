// lib/services/sound_recorder_service.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

enum RecordingState { idle, recording, playing, error }

class SoundRecorderService extends ChangeNotifier {
  static final SoundRecorderService _instance = SoundRecorderService._internal();
  factory SoundRecorderService() => _instance;
  SoundRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  RecordingState _state = RecordingState.idle;
  String? _currentRecordingPath;
  Duration _currentDuration = Duration.zero;
  Timer? _durationTimer;

  RecordingState get state => _state;
  String? get currentRecordingPath => _currentRecordingPath;
  Duration get currentDuration => _currentDuration;
  bool get isRecording => _state == RecordingState.recording;
  bool get isPlaying => _state == RecordingState.playing;
  bool get hasRecording => _currentRecordingPath != null;

  String get formattedDuration {
    final seconds = _currentDuration.inSeconds % 60;
    final ms = (_currentDuration.inMilliseconds % 1000) ~/ 10;
    return '${_currentDuration.inMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  double get recordingProgress =>
      _currentDuration.inMilliseconds /
      (AppConstants.soundscapeMaxDurationSeconds * 1000);

  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('SoundRecorder init error: $e');
    }
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Mulai merekam (maks 10 detik)
  Future<void> startRecording() async {
    if (_state == RecordingState.recording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _state = RecordingState.error;
      notifyListeners();
      throw Exception('Izin mikrofon diperlukan');
    }

    try {
      _currentDuration = Duration.zero;
      _state = RecordingState.recording;
      notifyListeners();

      final config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: AppConstants.soundscapeBitRate,
        sampleRate: AppConstants.soundscapeSampleRate,
        numChannels: 1,
      );

      // Pada web, path null/kosong akan menghasilkan Blob URL
      String? path;
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        path = '${dir.path}/soundscape_$timestamp.m4a';
      }

      await _recorder.start(config, path: path ?? '');

      // Timer: update setiap 50ms untuk feedback lancar
      _durationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        _currentDuration += const Duration(milliseconds: 50);
        notifyListeners();

        if (_currentDuration.inSeconds >= AppConstants.soundscapeMaxDurationSeconds) {
          stopRecording();
          timer.cancel();
        }
      });
    } catch (e) {
      debugPrint('startRecording error: $e');
      _state = RecordingState.error;
      notifyListeners();
      rethrow;
    }
  }

  /// Hentikan rekaman
  Future<String?> stopRecording() async {
    if (_state != RecordingState.recording) return null;

    _durationTimer?.cancel();

    try {
      final path = await _recorder.stop();
      _state = RecordingState.idle;

      // Validasi durasi minimal
      if (_currentDuration.inSeconds < AppConstants.soundscapeMinDurationSeconds) {
        // Hapus jika file (hanya non-web)
        if (!kIsWeb && path != null && await File(path).exists()) {
          await File(path).delete();
        }
        _currentRecordingPath = null;
        notifyListeners();
        throw Exception(
            'Rekaman terlalu pendek (minimal ${AppConstants.soundscapeMinDurationSeconds} detik)');
      }

      _currentRecordingPath = path;
      notifyListeners();
      return path;
    } catch (e) {
      debugPrint('stopRecording error: $e');
      _state = RecordingState.error;
      notifyListeners();
      rethrow;
    }
  }

  /// Putar preview rekaman
  Future<void> playPreview(String filePath) async {
    if (_state == RecordingState.playing) {
      await _player.stop();
    }

    _state = RecordingState.playing;
    notifyListeners();

    try {
      if (kIsWeb) {
        // Di web, path adalah Blob URL
        await _player.play(UrlSource(filePath));
      } else {
        await _player.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      _state = RecordingState.idle;
      notifyListeners();
      rethrow;
    }

    _player.onPlayerComplete.listen((_) {
      _state = RecordingState.idle;
      notifyListeners();
    });
  }

  /// Hentikan preview
  Future<void> stopPreview() async {
    await _player.stop();
    _state = RecordingState.idle;
    notifyListeners();
  }

  /// Hapus rekaman
  Future<void> deleteRecording(String filePath) async {
    try {
      if (!kIsWeb) {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      }
      if (_currentRecordingPath == filePath) {
        _currentRecordingPath = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('deleteRecording error: $e');
    }
  }

  /// Reset state
  void reset() {
    _durationTimer?.cancel();
    _state = RecordingState.idle;
    _currentRecordingPath = null;
    _currentDuration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
