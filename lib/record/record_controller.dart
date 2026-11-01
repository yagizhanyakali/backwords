import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_clip.dart';
import '../core/audio/audio_reverser.dart';
import '../core/audio/recorder_service.dart';
import '../core/audio/temp_files.dart';

enum RecorderPhase {
  idle,
  recording,
  processing,
  permissionDenied,
  permissionBlocked,
  error,
}

class RecorderState {
  const RecorderState({
    this.phase = RecorderPhase.idle,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.result,
    this.message,
  });

  final RecorderPhase phase;
  final Duration elapsed;
  final List<double> levels;

  /// Set once when a recording has been captured and reversed. The screen
  /// reacts to it and calls [RecorderController.consumeResult].
  final ClipPair? result;

  /// Short notice for the idle/error states, e.g. "Too short".
  final String? message;

  bool get isRecording => phase == RecorderPhase.recording;
  bool get isBusy => phase == RecorderPhase.processing;

  RecorderState copyWith({
    RecorderPhase? phase,
    Duration? elapsed,
    List<double>? levels,
    ClipPair? result,
    bool clearResult = false,
    String? message,
    bool clearMessage = false,
  }) =>
      RecorderState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        levels: levels ?? this.levels,
        result: clearResult ? null : (result ?? this.result),
        message: clearMessage ? null : (message ?? this.message),
      );
}

/// Drives one record -> reverse cycle. Used by the record screen and by both
/// recording steps of challenge mode, each through its own provider.
class RecorderController extends Notifier<RecorderState> {
  static const maxDuration = Duration(seconds: 30);
  static const minDuration = Duration(milliseconds: 400);
  static const _maxLevels = 64;
  static const _startTimeout = Duration(seconds: 8);

  late final TempFiles _temp;
  late final RecorderService _service;
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;
  StreamSubscription<double>? _levelSub;

  @override
  RecorderState build() {
    _temp = ref.read(tempFilesProvider);
    _service = RecorderService();
    ref.onDispose(() {
      _ticker?.cancel();
      _levelSub?.cancel();
      unawaited(_service.dispose());
    });
    return const RecorderState();
  }

  Future<void> toggle() async {
    switch (state.phase) {
      case RecorderPhase.recording:
        await _finish();
      case RecorderPhase.processing:
        return;
      default:
        await _start();
    }
  }

  void consumeResult() =>
      state = state.copyWith(clearResult: true, levels: const [], elapsed: Duration.zero);

  Future<void> _start() async {
    final permission = await _service.ensurePermission();
    if (!ref.mounted) return;
    if (permission != MicPermission.granted) {
      state = RecorderState(
        phase: permission == MicPermission.permanentlyDenied
            ? RecorderPhase.permissionBlocked
            : RecorderPhase.permissionDenied,
      );
      return;
    }

    try {
      final recPath = await _temp.newPath('rec');
      await _service.start(recPath).timeout(_startTimeout);
    } catch (_) {
      // If the platform call is merely slow, make sure it can't begin
      // recording after we've reported failure.
      unawaited(_service.cancel());
      if (!ref.mounted) return;
      state = const RecorderState(
        phase: RecorderPhase.error,
        message: 'Could not start the microphone. Please try again.',
      );
      return;
    }
    if (!ref.mounted) return;

    _clock
      ..reset()
      ..start();
    _levelSub = _service.levels().listen((level) {
      final levels = [...state.levels, level];
      state = state.copyWith(
        levels: levels.length > _maxLevels
            ? levels.sublist(levels.length - _maxLevels)
            : levels,
      );
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_clock.elapsed >= maxDuration) {
        _finish();
      } else {
        state = state.copyWith(elapsed: _clock.elapsed);
      }
    });
    state = const RecorderState(phase: RecorderPhase.recording);
  }

  Future<void> _finish() async {
    if (state.phase != RecorderPhase.recording) return;
    _ticker?.cancel();
    final elapsed = _clock.elapsed < maxDuration ? _clock.elapsed : maxDuration;
    _clock.stop();
    state = state.copyWith(phase: RecorderPhase.processing, elapsed: elapsed);
    await _levelSub?.cancel();

    String? recordedPath;
    try {
      recordedPath = await _service.stop();
      if (!ref.mounted) {
        await _temp.delete([recordedPath]);
        return;
      }
      if (recordedPath == null || elapsed < minDuration) {
        await _temp.delete([recordedPath]);
        state = const RecorderState(message: 'Too short! Hold on a little longer.');
        return;
      }

      final reversedPath = await _temp.newPath('rev');
      final pair = await reverseRecording(
        inputPath: recordedPath,
        outputPath: reversedPath,
      );
      if (!ref.mounted) {
        await _temp.delete(pair.paths);
        return;
      }
      state = RecorderState(result: pair);
    } catch (_) {
      await _temp.delete([recordedPath]);
      if (!ref.mounted) return;
      state = const RecorderState(
        phase: RecorderPhase.error,
        message: 'Something went wrong with that recording. Please try again.',
      );
    }
  }
}

/// The main record screen's recorder.
final recordScreenRecorderProvider =
    NotifierProvider.autoDispose<RecorderController, RecorderState>(
  RecorderController.new,
);
