import 'package:flutter/services.dart';

/// iOS-only offline pitch shifting (see `ios/Runner/PitchShifter.swift`).
///
/// just_audio's `setPitch` only works on Android, so on iOS a shifted copy of
/// the clip is rendered natively and played instead. Duration is unchanged.
class PitchShifter {
  static const _channel = MethodChannel('com.backwords/pitch');

  /// Writes [input] shifted by the factor [pitch] (2.0 = one octave up) to
  /// [output], as 16-bit PCM WAV.
  Future<void> shift({
    required String input,
    required String output,
    required double pitch,
  }) =>
      _channel.invokeMethod<void>('shift', {
        'input': input,
        'output': output,
        'pitch': pitch,
      });
}
