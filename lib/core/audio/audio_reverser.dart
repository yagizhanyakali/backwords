import 'dart:io';
import 'dart:isolate';

import 'audio_clip.dart';
import 'wav_codec.dart';

/// Reads the WAV at [inputPath], writes its reversal to [outputPath] and
/// returns both clips. All parsing, reversing and file I/O happens on a
/// background isolate so the UI thread never stutters.
Future<ClipPair> reverseRecording({
  required String inputPath,
  required String outputPath,
}) =>
    Isolate.run(() => reverseRecordingSync(inputPath, outputPath));

/// Synchronous body of [reverseRecording]; public so tests can call it directly.
ClipPair reverseRecordingSync(String inputPath, String outputPath) {
  final original = parseWav(File(inputPath).readAsBytesSync());
  final reversed = reverseWav(original);
  File(outputPath).writeAsBytesSync(encodeWav(reversed), flush: true);
  return ClipPair(
    original: AudioClip(
      path: inputPath,
      duration: original.duration,
      peaks: computePeaks(original),
    ),
    reversed: AudioClip(
      path: outputPath,
      duration: reversed.duration,
      peaks: computePeaks(reversed),
    ),
  );
}
