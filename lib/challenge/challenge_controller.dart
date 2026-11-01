import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_clip.dart';
import '../core/audio/temp_files.dart';
import '../record/record_controller.dart';

enum ChallengeStep { record, practice, imitate, compare }

class ChallengeState {
  const ChallengeState({
    this.step = ChallengeStep.record,
    this.original,
    this.imitation,
  });

  final ChallengeStep step;

  /// Step 1: the user's original clip and its reversal (played in step 2).
  final ClipPair? original;

  /// Step 3: the user's imitation of the reversed sound, and that imitation
  /// reversed back (played against the original in step 4).
  final ClipPair? imitation;
}

class ChallengeController extends Notifier<ChallengeState> {
  late final TempFiles _temp;
  final Set<String> _owned = {};

  @override
  ChallengeState build() {
    _temp = ref.read(tempFilesProvider);
    ref.onDispose(() => _temp.delete(_owned));
    return const ChallengeState();
  }

  void setOriginal(ClipPair pair) {
    _owned.addAll(pair.paths);
    state = ChallengeState(step: ChallengeStep.practice, original: pair);
  }

  void startImitating() => _goTo(ChallengeStep.imitate);

  void backToPractice() => _goTo(ChallengeStep.practice);

  void setImitation(ClipPair pair) {
    final old = state.imitation;
    _owned.addAll(pair.paths);
    state = ChallengeState(
      step: ChallengeStep.compare,
      original: state.original,
      imitation: pair,
    );
    if (old != null) {
      _owned.removeAll(old.paths);
      _temp.delete(old.paths);
    }
  }

  /// Starts over with a new original recording.
  void restart() {
    final files = _owned.toList();
    _owned.clear();
    state = const ChallengeState();
    _temp.delete(files);
  }

  void _goTo(ChallengeStep step) => state = ChallengeState(
        step: step,
        original: state.original,
        imitation: state.imitation,
      );
}

final challengeProvider =
    NotifierProvider.autoDispose<ChallengeController, ChallengeState>(
  ChallengeController.new,
);

/// Separate recorder instances for steps 1 and 3 so they never share state
/// with the main record screen that sits underneath this one.
final challengeRecorderProvider =
    NotifierProvider.autoDispose<RecorderController, RecorderState>(
  RecorderController.new,
);
