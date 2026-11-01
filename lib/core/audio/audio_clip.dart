/// A WAV file on disk plus what the UI needs to draw it.
class AudioClip {
  const AudioClip({
    required this.path,
    required this.duration,
    required this.peaks,
  });

  final String path;
  final Duration duration;
  final List<double> peaks;
}

/// A recording and its reversed twin.
class ClipPair {
  const ClipPair({required this.original, required this.reversed});

  final AudioClip original;
  final AudioClip reversed;

  List<String> get paths => [original.path, reversed.path];

  @override
  bool operator ==(Object other) =>
      other is ClipPair &&
      other.original.path == original.path &&
      other.reversed.path == reversed.path;

  @override
  int get hashCode => Object.hash(original.path, reversed.path);
}
