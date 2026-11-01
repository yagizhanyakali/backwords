import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum MicPermission { granted, denied, permanentlyDenied }

/// Thin wrapper over `record` + `permission_handler`: mic permission, WAV
/// capture to a file, and a normalised live level stream for the waveform.
class RecorderService {
  RecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 44100,
    numChannels: 1,
  );

  /// Quietest level (dBFS) that still moves the waveform.
  static const _floorDb = -50.0;

  final AudioRecorder _recorder;

  Future<MicPermission> ensurePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }
    return MicPermission.denied;
  }

  Future<void> start(String path) => _recorder.start(_config, path: path);

  /// Live input level, 0..1.
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 60))
      .map((a) => ((a.current - _floorDb) / -_floorDb).clamp(0.0, 1.0));

  /// Stops and returns the file path, or null if nothing was recorded.
  Future<String?> stop() => _recorder.stop();

  /// Stops and deletes the partial file.
  Future<void> cancel() => _recorder.cancel();

  Future<void> dispose() async {
    if (await _recorder.isRecording()) await _recorder.cancel();
    await _recorder.dispose();
  }
}
