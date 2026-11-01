import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/audio/audio_clip.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/record_button.dart';
import '../core/widgets/waveform.dart';
import 'record_controller.dart';

String formatDuration(Duration d) {
  final tenths = d.inMilliseconds ~/ 100;
  final s = tenths ~/ 10;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}.${tenths % 10}';
}

/// Live waveform, timer, big record button and permission messaging for one
/// [RecorderController]. Calls [onClip] with the recorded + reversed pair.
class RecorderPad extends ConsumerWidget {
  const RecorderPad({
    super.key,
    required this.provider,
    required this.onClip,
    required this.idleHint,
  });

  final NotifierProvider<RecorderController, RecorderState> provider;
  final ValueChanged<ClipPair> onClip;
  final String idleHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider.select((s) => s.result), (_, clip) {
      if (clip == null) return;
      controller.consumeResult();
      onClip(clip);
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LiveWaveform(levels: state.levels, active: state.isRecording),
        const SizedBox(height: 12),
        Text(
          '${formatDuration(state.elapsed)} / 00:30',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 16),
        RecordButton(
          recording: state.isRecording,
          busy: state.isBusy,
          progress: state.elapsed.inMilliseconds /
              RecorderController.maxDuration.inMilliseconds,
          onPressed: controller.toggle,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _Status(key: ValueKey(state.phase), state: state, idleHint: idleHint),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({super.key, required this.state, required this.idleHint});

  final RecorderState state;
  final String idleHint;

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case RecorderPhase.permissionDenied:
        return const _Notice(
          icon: Icons.mic_off_rounded,
          text: 'Backwords needs the microphone to record. '
              'Tap the button to try again.',
        );
      case RecorderPhase.permissionBlocked:
        return _Notice(
          icon: Icons.lock_rounded,
          text: 'Microphone access is turned off. '
              'Enable it in Settings to record.',
          action: FilledButton(
            onPressed: openAppSettings,
            child: const Text('Open Settings'),
          ),
        );
      case RecorderPhase.error:
        return _Notice(icon: Icons.error_outline_rounded, text: state.message ?? '');
      case RecorderPhase.recording:
        return const Text(
          'Recording… tap to stop',
          style: TextStyle(color: AppColors.pink, fontWeight: FontWeight.w800, fontSize: 16),
        );
      case RecorderPhase.processing:
        return const Text(
          'Flipping it backwards…',
          style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800, fontSize: 16),
        );
      case RecorderPhase.idle:
        return Text(
          state.message ?? idleHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: state.message == null ? AppColors.textDim : AppColors.cyan,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.cyan, size: 28),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text, fontSize: 15),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
