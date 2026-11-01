import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../challenge/challenge_screen.dart';
import '../core/audio/audio_clip.dart';
import '../core/theme/app_theme.dart';
import '../playback/playback_screen.dart';
import 'record_controller.dart';
import 'recorder_pad.dart';

/// Home screen: one big button. Record, then see and hear it backwards.
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const _Wordmark(),
              Expanded(
                child: RecorderPad(
                  provider: recordScreenRecorderProvider,
                  idleHint: 'Tap to record up to 30 seconds',
                  onClip: (ClipPair pair) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlaybackScreen(pair: pair),
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ChallengeScreen()),
                ),
                icon: const Icon(Icons.emoji_events_rounded, color: AppColors.lime),
                label: const Text('Challenge mode'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1),
        children: [
          TextSpan(text: 'Back', style: TextStyle(color: AppColors.pink)),
          TextSpan(text: 'words', style: TextStyle(color: AppColors.lime)),
        ],
      ),
    );
  }
}
