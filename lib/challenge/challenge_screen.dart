import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_clip.dart';
import '../core/theme/app_theme.dart';
import '../playback/player_panel.dart';
import '../playback/playback_controller.dart';
import '../record/recorder_pad.dart';
import 'challenge_controller.dart';

/// Say it, hear it backwards, imitate the backwards sound, then reverse the
/// imitation to see how close you got.
class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(challengeProvider);
    final controller = ref.read(challengeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Challenge')),
      body: SafeArea(
        child: Column(
          children: [
            _StepBar(current: state.step),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(state.step),
                  child: switch (state.step) {
                    ChallengeStep.record => _RecordStep(
                        title: '1. Say or sing something',
                        hint: 'A short phrase works best.',
                        onClip: controller.setOriginal,
                      ),
                    ChallengeStep.practice => _PracticeStep(
                        state: state,
                        controller: controller,
                      ),
                    ChallengeStep.imitate => _RecordStep(
                        title: '3. Now imitate the backwards sound',
                        hint: 'Copy exactly what you heard.',
                        onClip: controller.setImitation,
                        secondary: TextButton(
                          onPressed: controller.backToPractice,
                          child: const Text('Back to practice'),
                        ),
                      ),
                    ChallengeStep.compare => _CompareStep(
                        state: state,
                        controller: controller,
                      ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordStep extends StatelessWidget {
  const _RecordStep({
    required this.title,
    required this.hint,
    required this.onClip,
    this.secondary,
  });

  final String title;
  final String hint;
  final ValueChanged<ClipPair> onClip;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: _titleStyle),
          Expanded(
            child: RecorderPad(
              provider: challengeRecorderProvider,
              idleHint: hint,
              onClip: onClip,
            ),
          ),
          ?secondary,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PracticeStep extends StatelessWidget {
  const _PracticeStep({required this.state, required this.controller});

  final ChallengeState state;
  final ChallengeController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          const Text('2. Listen backwards and practice',
              textAlign: TextAlign.center, style: _titleStyle),
          const SizedBox(height: 4),
          const Text(
            'Slow it down if you like, then try to copy the sound.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 15),
          ),
          const SizedBox(height: 16),
          PlayerPanel(
            args: PlaybackArgs(state.original!),
            title: 'Reversed clip',
            showToggle: false,
            showShare: false,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.startImitating,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('I’m ready, record my imitation'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.restart,
            child: const Text('Start over with a new clip'),
          ),
        ],
      ),
    );
  }
}

class _CompareStep extends StatelessWidget {
  const _CompareStep({required this.state, required this.controller});

  final ChallengeState state;
  final ChallengeController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          const Text('4. How close did you get?',
              textAlign: TextAlign.center, style: _titleStyle),
          const SizedBox(height: 4),
          const Text(
            'Your imitation, flipped back, next to the original.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 15),
          ),
          const SizedBox(height: 16),
          PlayerPanel(
            args: PlaybackArgs(state.original!, startReversed: false),
            title: 'Original',
            compact: true,
            showShare: false,
            accent: AppColors.cyan,
          ),
          const SizedBox(height: 12),
          PlayerPanel(
            args: PlaybackArgs(state.imitation!),
            title: 'Your imitation, reversed back',
            compact: true,
            accent: AppColors.pink,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.backToPractice,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Try the imitation again'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: controller.restart,
            child: const Text('New challenge'),
          ),
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w900,
  color: AppColors.text,
);

class _StepBar extends StatelessWidget {
  const _StepBar({required this.current});

  final ChallengeStep current;

  static const _labels = ['Record', 'Practice', 'Imitate', 'Compare'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: Semantics(
                label: 'Step ${i + 1}: ${_labels[i]}'
                    '${i == current.index ? ', current' : ''}',
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i < current.index
                            ? AppColors.cyan
                            : i == current.index
                                ? AppColors.lime
                                : AppColors.surfaceHigh,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: i == current.index
                            ? AppColors.text
                            : AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
