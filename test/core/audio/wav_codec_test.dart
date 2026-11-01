import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:backwords/core/audio/audio_reverser.dart';
import 'package:backwords/core/audio/wav_codec.dart';
import 'package:flutter_test/flutter_test.dart';

WavAudio _audio(List<int> samples, {int channels = 1, int rate = 44100}) =>
    WavAudio(
      sampleRate: rate,
      channels: channels,
      samples: Int16List.fromList(samples),
    );

Int16List _random(int length, {int seed = 7}) {
  final rng = Random(seed);
  return Int16List.fromList(
    List.generate(length, (_) => rng.nextInt(65536) - 32768),
  );
}

/// Builds a WAV by hand so parser tests don't depend on [encodeWav].
Uint8List _rawWav({
  required List<int> pcm,
  int channels = 1,
  int rate = 8000,
  int bits = 16,
  int format = 1,
  List<List<int>> extraChunksBeforeData = const [],
  int? dataSizeOverride,
  List<int> trailingBytes = const [],
}) {
  final b = BytesBuilder();
  void u16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
  void u32(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void tag(String s) => b.add(s.codeUnits);

  tag('RIFF');
  u32(0); // RIFF size is ignored by the parser
  tag('WAVE');
  tag('fmt ');
  u32(16);
  u16(format);
  u16(channels);
  u32(rate);
  u32(rate * channels * bits ~/ 8);
  u16(channels * bits ~/ 8);
  u16(bits);
  for (final chunk in extraChunksBeforeData) {
    b.add(chunk);
  }
  tag('data');
  u32(dataSizeOverride ?? pcm.length);
  b.add(pcm);
  b.add(trailingBytes);
  return b.toBytes();
}

List<int> _pcm(List<int> samples) {
  final d = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    d.setInt16(i * 2, samples[i], Endian.little);
  }
  return d.buffer.asUint8List();
}

void main() {
  group('reverseFrames', () {
    test('reverses mono samples', () {
      final out = reverseFrames(Int16List.fromList([1, 2, 3, 4]), 1);
      expect(out, [4, 3, 2, 1]);
    });

    test('reverses stereo by frame so channels do not swap', () {
      // Frames: (L1,R1) (L2,R2) (L3,R3)
      final out = reverseFrames(Int16List.fromList([1, -1, 2, -2, 3, -3]), 2);
      expect(out, [3, -3, 2, -2, 1, -1]);
    });

    test('handles odd frame counts (mono)', () {
      expect(reverseFrames(Int16List.fromList([1, 2, 3, 4, 5]), 1),
          [5, 4, 3, 2, 1]);
    });

    test('handles odd frame counts (stereo)', () {
      final out = reverseFrames(Int16List.fromList([10, 11, 20, 21, 30, 31]), 2);
      expect(out, [30, 31, 20, 21, 10, 11]);
    });

    test('handles a single frame and empty input', () {
      expect(reverseFrames(Int16List.fromList([5, 6]), 2), [5, 6]);
      expect(reverseFrames(Int16List(0), 2), isEmpty);
    });

    test('rejects a sample count that is not whole frames', () {
      expect(() => reverseFrames(Int16List(5), 2), throwsArgumentError);
      expect(() => reverseFrames(Int16List(4), 0), throwsArgumentError);
    });

    test('does not mutate its input', () {
      final input = Int16List.fromList([1, 2, 3]);
      reverseFrames(input, 1);
      expect(input, [1, 2, 3]);
    });

    for (final channels in [1, 2]) {
      test('reversing twice returns the original ($channels ch)', () {
        for (final frames in [0, 1, 2, 3, 99, 1001]) {
          final original = _random(frames * channels);
          final twice = reverseFrames(reverseFrames(original, channels), channels);
          expect(twice, original, reason: '$frames frames');
        }
      });
    }
  });

  group('encodeWav / parseWav', () {
    test('writes a valid canonical header', () {
      final bytes = encodeWav(_audio([1, 2, 3, 4], channels: 2, rate: 22050));
      final d = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      expect(bytes.length, 44 + 8);
      expect(d.getUint32(4, Endian.little), bytes.length - 8);
      expect(d.getUint32(16, Endian.little), 16);
      expect(d.getUint16(20, Endian.little), 1); // PCM
      expect(d.getUint16(22, Endian.little), 2); // channels
      expect(d.getUint32(24, Endian.little), 22050);
      expect(d.getUint32(28, Endian.little), 22050 * 2 * 2); // byte rate
      expect(d.getUint16(32, Endian.little), 4); // block align
      expect(d.getUint16(34, Endian.little), 16);
      expect(d.getUint32(40, Endian.little), 8);
    });

    test('round-trips samples including extremes', () {
      final audio = _audio([0, 1, -1, 32767, -32768], rate: 16000);
      final parsed = parseWav(encodeWav(audio));
      expect(parsed.samples, audio.samples);
      expect(parsed.sampleRate, 16000);
      expect(parsed.channels, 1);
    });

    test('reverseWavBytes twice yields identical bytes', () {
      final bytes = encodeWav(WavAudio(
        sampleRate: 44100,
        channels: 2,
        samples: _random(2 * 301),
      ));
      expect(reverseWavBytes(reverseWavBytes(bytes)), bytes);
    });

    test('reverseWavBytes keeps format fields', () {
      final reversed = parseWav(reverseWavBytes(encodeWav(
        _audio([1, -1, 2, -2, 3, -3], channels: 2, rate: 48000),
      )));
      expect(reversed.channels, 2);
      expect(reversed.sampleRate, 48000);
      expect(reversed.samples, [3, -3, 2, -2, 1, -1]);
    });

    test('skips unknown chunks and their pad bytes', () {
      final bytes = _rawWav(
        pcm: _pcm([7, 8, 9]),
        // "LIST" chunk with an odd size (3) followed by a pad byte.
        extraChunksBeforeData: [
          [...'LIST'.codeUnits, 3, 0, 0, 0, 1, 2, 3, 0],
        ],
      );
      expect(parseWav(bytes).samples, [7, 8, 9]);
    });

    test('drops a trailing partial frame', () {
      // Stereo: 2 full frames (8 bytes) + 3 stray bytes.
      final bytes = _rawWav(
        channels: 2,
        pcm: [..._pcm([1, 2, 3, 4]), 9, 9, 9],
      );
      expect(parseWav(bytes).samples, [1, 2, 3, 4]);
    });

    test('clamps a data size that overruns the file', () {
      final bytes = _rawWav(
        pcm: _pcm([1, 2, 3]),
        dataSizeOverride: 0xFFFFFFFF,
      );
      expect(parseWav(bytes).samples, [1, 2, 3]);
    });

    test('accepts WAVE_FORMAT_EXTENSIBLE carrying PCM', () {
      final b = BytesBuilder();
      void u16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
      void u32(int v) => b.add(
          [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
      b.add('RIFF'.codeUnits);
      u32(0);
      b.add('WAVEfmt '.codeUnits);
      u32(40);
      u16(0xFFFE);
      u16(1);
      u32(8000);
      u32(16000);
      u16(2);
      u16(16);
      u16(22); // cbSize
      u16(16); // valid bits
      u32(4); // channel mask
      u16(1); // sub-format GUID starts with the PCM tag
      b.add(List.filled(14, 0));
      b.add('data'.codeUnits);
      u32(4);
      b.add(_pcm([5, 6]));
      expect(parseWav(b.toBytes()).samples, [5, 6]);
    });

    test('rejects non-WAV, 8-bit and float files', () {
      expect(() => parseWav(Uint8List(4)), throwsA(isA<WavFormatException>()));
      expect(() => parseWav(Uint8List(64)), throwsA(isA<WavFormatException>()));
      expect(() => parseWav(_rawWav(pcm: [1, 2], bits: 8)),
          throwsA(isA<WavFormatException>()));
      expect(() => parseWav(_rawWav(pcm: [1, 2], format: 3)),
          throwsA(isA<WavFormatException>()));
    });

    test('rejects a file with no data chunk', () {
      final bytes = _rawWav(pcm: const []).sublist(0, 36);
      expect(() => parseWav(bytes), throwsA(isA<WavFormatException>()));
    });
  });

  group('WavAudio / computePeaks', () {
    test('duration and frameCount', () {
      final a = _audio(List.filled(8000, 0), channels: 2, rate: 8000);
      expect(a.frameCount, 4000);
      expect(a.duration, const Duration(milliseconds: 500));
    });

    test('peaks follow the loudest sample in each bin', () {
      final a = _audio([0, 0, 16384, 0, -32768, 0, 0, 0]);
      final peaks = computePeaks(a, bins: 4);
      expect(peaks, [0, 0.5, 1.0, 0]);
    });

    test('peaks of empty audio are zeros; short audio still fills bins', () {
      expect(computePeaks(_audio([]), bins: 3), [0, 0, 0]);
      expect(computePeaks(_audio([32767]), bins: 4).length, 4);
    });
  });

  group('reverseRecording (isolate)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('backwords_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes a reversed file and returns both clips', () async {
      final input = '${dir.path}/in.wav';
      final output = '${dir.path}/out.wav';
      final samples = [1, -1, 2, -2, 3, -3];
      File(input).writeAsBytesSync(encodeWav(_audio(samples, channels: 2)));

      final pair = await reverseRecording(inputPath: input, outputPath: output);

      expect(pair.original.path, input);
      expect(pair.reversed.path, output);
      expect(parseWav(File(output).readAsBytesSync()).samples,
          [3, -3, 2, -2, 1, -1]);
      expect(pair.original.peaks.length, 64);
      expect(pair.reversed.duration, pair.original.duration);
    });

    test('surfaces format errors from the isolate', () async {
      final input = '${dir.path}/bad.wav';
      File(input).writeAsBytesSync([1, 2, 3]);
      expect(
        reverseRecording(inputPath: input, outputPath: '${dir.path}/o.wav'),
        throwsA(isA<WavFormatException>()),
      );
    });
  });
}
