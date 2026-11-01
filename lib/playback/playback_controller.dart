import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/audio/audio_clip.dart';
import '../core/audio/pitch_shifter.dart';
import '../core/audio/temp_files.dart';

/// What a player shows: a clip pair and which side it opens on.
class PlaybackArgs {
  const PlaybackArgs(this.pair, {this.startReversed = true});

  final ClipPair pair;
  final bool startReversed;

  @override
  bool operator ==(Object other) =>
      other is PlaybackArgs &&
      other.pair == pair &&
      other.startReversed == startReversed;

  @override
  int get hashCode => Object.hash(pair, startReversed);
}

class PlaybackState {
  const PlaybackState({
    required this.reversed,
    required this.duration,
    this.loaded = false,
    this.playing = false,
    this.position = Duration.zero,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.error,
  });

  final bool reversed;
  final Duration duration;
  final bool loaded;
  final bool playing;
  final Duration position;
  final double speed;
  final double pitch;
  final String? error;

  double get progress => duration.inMicroseconds == 0
      ? 0
      : (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);

  PlaybackState copyWith({
    bool? reversed,
    Duration? duration,
    bool? loaded,
    bool? playing,
    Duration? position,
    double? speed,
    double? pitch,
    String? error,
    bool clearError = false,
  }) =>
      PlaybackState(
        reversed: reversed ?? this.reversed,
        duration: duration ?? this.duration,
        loaded: loaded ?? this.loaded,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        speed: speed ?? this.speed,
        pitch: pitch ?? this.pitch,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Android uses just_audio's `setPitch`. just_audio can't do it on iOS, so
/// there a pitch-shifted copy is rendered natively and played instead.
bool get _nativePitchRender => Platform.isIOS;

/// Which player (if any) is allowed to be playing, so two panels shown side by
/// side never play over each other.
class _NowPlaying extends Notifier<PlaybackArgs?> {
  @override
  PlaybackArgs? build() => null;

  // ignore: use_setters_to_change_properties
  void claim(PlaybackArgs? who) => state = who;
}

final _nowPlayingProvider =
    NotifierProvider<_NowPlaying, PlaybackArgs?>(_NowPlaying.new);

class PlaybackController extends Notifier<PlaybackState> {
  PlaybackController(this.args);

  final PlaybackArgs args;
  late AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subs = [];
  final _shifter = PitchShifter();
  late final TempFiles _temp;

  /// Rendered iOS files, keyed by source path and pitch.
  final Map<String, String> _shifted = {};
  Timer? _pitchDebounce;
  int _pitchGeneration = 0;

  AudioClip _clipFor(bool reversed) =>
      reversed ? args.pair.reversed : args.pair.original;

  @override
  PlaybackState build() {
    _player = AudioPlayer();
    _temp = ref.read(tempFilesProvider);
    ref.onDispose(() {
      _pitchDebounce?.cancel();
      for (final s in _subs) {
        s.cancel();
      }
      _player.dispose();
      _temp.delete(_shifted.values);
    });

    _subs
      ..add(_player.playerStateStream.listen(_onPlayerState))
      ..add(_player.positionStream.listen((p) {
        if (ref.mounted) state = state.copyWith(position: p);
      }));

    ref.listen(_nowPlayingProvider, (_, who) {
      if (who != args && _player.playing) _player.pause();
    });

    final initial = _clipFor(args.startReversed);
    unawaited(_load(initial.path));
    return PlaybackState(reversed: args.startReversed, duration: initial.duration);
  }

  Future<void> _load(String path, {Duration? initialPosition}) async {
    try {
      await _player.setFilePath(path, initialPosition: initialPosition);
      await _player.setSpeed(state.speed);
      if (Platform.isAndroid) await _player.setPitch(state.pitch);
      if (ref.mounted) {
        state = state.copyWith(
          loaded: true,
          duration: _player.duration ?? state.duration,
          clearError: true,
        );
      }
    } catch (_) {
      if (ref.mounted) state = state.copyWith(error: 'Could not play this clip.');
    }
  }

  Future<void> _onPlayerState(PlayerState s) async {
    if (!ref.mounted) return;
    if (s.processingState == ProcessingState.completed) {
      // Rewind so the next tap on play starts from the top.
      await _player.pause();
      await _player.seek(Duration.zero);
      if (ref.mounted) state = state.copyWith(playing: false, position: Duration.zero);
      return;
    }
    state = state.copyWith(playing: s.playing);
  }

  Future<void> togglePlay() async {
    if (!state.loaded) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      ref.read(_nowPlayingProvider.notifier).claim(args);
      unawaited(_player.play()); // completes only when playback ends
    }
  }

  Future<void> seekToFraction(double fraction) async {
    if (!state.loaded) return;
    final target = state.duration * fraction;
    state = state.copyWith(position: target);
    await _player.seek(target);
  }

  /// The file to play for [clip] at the current pitch. On iOS that's a
  /// rendered, cached copy whenever the pitch isn't 1.0.
  Future<String> _pathFor(AudioClip clip) async {
    final pitch = state.pitch;
    if (!_nativePitchRender || pitch == 1.0) return clip.path;
    final key = '${clip.path}@$pitch';
    final cached = _shifted[key];
    if (cached != null) return cached;
    final output = await _temp.newPath('pitch');
    await _shifter.shift(input: clip.path, output: output, pitch: pitch);
    return _shifted[key] = output;
  }

  /// Reloads the current clip at the current pitch, keeping position and
  /// play state (iOS only).
  Future<void> _applyPitch(int generation) async {
    final wasPlaying = _player.playing;
    final position = _player.position;
    final clip = _clipFor(state.reversed);
    state = state.copyWith(loaded: false);
    await _player.pause();
    try {
      final path = await _pathFor(clip);
      if (!ref.mounted || generation != _pitchGeneration) return;
      await _load(path, initialPosition: position);
      if (wasPlaying && ref.mounted && generation == _pitchGeneration) {
        unawaited(_player.play());
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(error: 'Could not change the pitch.');
      }
    }
  }

  /// Switches between the original and the reversed clip, keeping the same
  /// moment of the sound under the playhead (position p becomes duration - p).
  /// A playhead sitting at the very start stays at the start.
  Future<void> setReversed(bool reversed) async {
    if (reversed == state.reversed || !state.loaded) return;
    final wasPlaying = _player.playing;
    final position = _player.position;
    final mirrored = position > Duration.zero && position < state.duration
        ? state.duration - position
        : Duration.zero;
    final next = _clipFor(reversed);
    state = state.copyWith(reversed: reversed, loaded: false, duration: next.duration);
    await _player.pause();
    try {
      await _load(await _pathFor(next), initialPosition: mirrored);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(error: 'Could not change the pitch.');
    }
    if (wasPlaying && ref.mounted) unawaited(_player.play());
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await _player.setSpeed(speed);
  }

  Future<void> setPitch(double pitch) async {
    state = state.copyWith(pitch: pitch);
    if (Platform.isAndroid) {
      await _player.setPitch(pitch);
    } else if (_nativePitchRender) {
      // The slider fires continuously; render once it settles.
      final generation = ++_pitchGeneration;
      _pitchDebounce?.cancel();
      _pitchDebounce = Timer(
        const Duration(milliseconds: 250),
        () => _applyPitch(generation),
      );
    }
  }

  Future<void> resetTuning() async {
    await setSpeed(1.0);
    await setPitch(1.0);
  }
}

final playbackProvider = NotifierProvider.autoDispose
    .family<PlaybackController, PlaybackState, PlaybackArgs>(
  PlaybackController.new,
);
