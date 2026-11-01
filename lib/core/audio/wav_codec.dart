import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart WAV (16-bit PCM) parsing, writing and reversing. No Flutter or
/// platform imports, so it can run in an isolate and under plain unit tests.

const int _headerSize = 44;
const int _bytesPerSample = 2;
const int _formatPcm = 1;
const int _formatExtensible = 0xFFFE;

class WavFormatException implements Exception {
  const WavFormatException(this.message);

  final String message;

  @override
  String toString() => 'WavFormatException: $message';
}

/// Decoded 16-bit PCM audio. [samples] is interleaved: for stereo the layout
/// is L0 R0 L1 R1 ..., so one *frame* is [channels] consecutive samples.
class WavAudio {
  const WavAudio({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;
  final Int16List samples;

  int get frameCount => samples.length ~/ channels;

  Duration get duration =>
      Duration(microseconds: frameCount * 1000000 ~/ sampleRate);
}

/// Parses a RIFF/WAVE file containing 16-bit integer PCM.
///
/// Walks the chunk list rather than assuming a 44-byte header, because
/// platform encoders may insert extra chunks (LIST, FLLR, ...). A trailing
/// partial frame is dropped, and a `data` chunk whose declared size runs past
/// the end of the file is clamped to the bytes that are actually there.
WavAudio parseWav(Uint8List bytes) {
  if (bytes.length < 12) {
    throw const WavFormatException('File too short to be a WAV file.');
  }
  final data = ByteData.sublistView(bytes);
  if (_tag(data, 0) != 'RIFF' || _tag(data, 8) != 'WAVE') {
    throw const WavFormatException('Missing RIFF/WAVE header.');
  }

  int? channels;
  int? sampleRate;
  int? dataStart;
  int? dataLength;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(data, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    final available = bytes.length - body;

    if (id == 'fmt ') {
      if (size < 16 || size > available) {
        throw const WavFormatException('Malformed fmt chunk.');
      }
      var format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      final bitsPerSample = data.getUint16(body + 14, Endian.little);
      if (format == _formatExtensible && size >= 26) {
        // The real format is the first two bytes of the sub-format GUID.
        format = data.getUint16(body + 24, Endian.little);
      }
      if (format != _formatPcm) {
        throw WavFormatException('Unsupported WAV format tag $format.');
      }
      if (bitsPerSample != 16) {
        throw WavFormatException(
          'Only 16-bit PCM is supported, got $bitsPerSample-bit.',
        );
      }
    } else if (id == 'data') {
      dataStart = body;
      dataLength = math.min(size, available);
    }

    // Chunks are word-aligned: odd sizes are followed by a pad byte.
    offset = body + size + (size & 1);
  }

  if (channels == null || sampleRate == null) {
    throw const WavFormatException('Missing fmt chunk.');
  }
  if (channels < 1 || sampleRate < 1) {
    throw const WavFormatException('Invalid channel count or sample rate.');
  }
  if (dataStart == null || dataLength == null) {
    throw const WavFormatException('Missing data chunk.');
  }

  final frameBytes = channels * _bytesPerSample;
  final usableBytes = dataLength - dataLength % frameBytes;
  final samples = Int16List(usableBytes ~/ _bytesPerSample);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = data.getInt16(dataStart + i * _bytesPerSample, Endian.little);
  }
  return WavAudio(
    sampleRate: sampleRate,
    channels: channels,
    samples: samples,
  );
}

/// Serialises [audio] as a canonical 44-byte-header PCM WAV file.
Uint8List encodeWav(WavAudio audio) {
  if (audio.samples.length % audio.channels != 0) {
    throw ArgumentError('Sample count is not a whole number of frames.');
  }
  final dataBytes = audio.samples.length * _bytesPerSample;
  if (dataBytes > 0xFFFFFFFF - (_headerSize - 8)) {
    throw ArgumentError('Audio is too large for a WAV file.');
  }

  final out = Uint8List(_headerSize + dataBytes);
  final d = ByteData.sublistView(out);
  final blockAlign = audio.channels * _bytesPerSample;

  _writeTag(d, 0, 'RIFF');
  d.setUint32(4, _headerSize - 8 + dataBytes, Endian.little);
  _writeTag(d, 8, 'WAVE');
  _writeTag(d, 12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, _formatPcm, Endian.little);
  d.setUint16(22, audio.channels, Endian.little);
  d.setUint32(24, audio.sampleRate, Endian.little);
  d.setUint32(28, audio.sampleRate * blockAlign, Endian.little);
  d.setUint16(32, blockAlign, Endian.little);
  d.setUint16(34, 16, Endian.little);
  _writeTag(d, 36, 'data');
  d.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < audio.samples.length; i++) {
    d.setInt16(_headerSize + i * _bytesPerSample, audio.samples[i], Endian.little);
  }
  return out;
}

/// Reverses interleaved [samples] frame by frame.
///
/// Reversing sample by sample would swap left and right on stereo audio; here
/// each frame's channels keep their order and only the frame order flips.
Int16List reverseFrames(Int16List samples, int channels) {
  if (channels < 1) {
    throw ArgumentError.value(channels, 'channels', 'Must be at least 1.');
  }
  if (samples.length % channels != 0) {
    throw ArgumentError.value(
      samples.length,
      'samples.length',
      'Must be a multiple of channels ($channels).',
    );
  }
  final frames = samples.length ~/ channels;
  final out = Int16List(samples.length);
  for (var f = 0; f < frames; f++) {
    final src = f * channels;
    final dst = (frames - 1 - f) * channels;
    for (var c = 0; c < channels; c++) {
      out[dst + c] = samples[src + c];
    }
  }
  return out;
}

WavAudio reverseWav(WavAudio audio) => WavAudio(
      sampleRate: audio.sampleRate,
      channels: audio.channels,
      samples: reverseFrames(audio.samples, audio.channels),
    );

/// Bytes in, reversed bytes out. The whole pipeline in one pure function.
Uint8List reverseWavBytes(Uint8List wavBytes) =>
    encodeWav(reverseWav(parseWav(wavBytes)));

/// Downsamples [audio] to [bins] amplitude peaks in 0..1 for drawing.
List<double> computePeaks(WavAudio audio, {int bins = 64}) {
  final frames = audio.frameCount;
  final peaks = List<double>.filled(bins, 0);
  if (frames == 0) return peaks;
  final channels = audio.channels;
  for (var b = 0; b < bins; b++) {
    final start = math.min(b * frames ~/ bins, frames - 1);
    final end = math.min(math.max((b + 1) * frames ~/ bins, start + 1), frames);
    var peak = 0;
    for (var i = start * channels; i < end * channels; i++) {
      final v = audio.samples[i].abs();
      if (v > peak) peak = v;
    }
    peaks[b] = math.min(peak / 32768, 1.0);
  }
  return peaks;
}

String _tag(ByteData d, int o) => String.fromCharCodes([
      d.getUint8(o),
      d.getUint8(o + 1),
      d.getUint8(o + 2),
      d.getUint8(o + 3),
    ]);

void _writeTag(ByteData d, int o, String tag) {
  for (var i = 0; i < 4; i++) {
    d.setUint8(o + i, tag.codeUnitAt(i));
  }
}
