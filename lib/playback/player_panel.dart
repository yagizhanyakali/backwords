import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/waveform.dart';
import '../record/recorder_pad.dart' show formatDuration;
import 'playback_controller.dart';
import 'share_clip.dart';

/// Waveform + transport controls for one clip pair. [compact] drops the
/// original/reversed toggle and the speed/pitch sliders.
class PlayerPanel extends ConsumerWidget {
  const PlayerPanel({
    super.key,
    required this.args,
    required this.title,
    this.compact = false,
    this.showToggle = true,
    this.showShare = true,
    this.accent = AppColors.lime,
  });

  final PlaybackArgs args;
  final String title;
  final bool compact;
  final bool showToggle;
  final bool showShare;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackProvider(args));
    final controller = ref.read(playbackProvider(args).notifier);
    final clip = state.reversed ? args.pair.reversed : args.pair.original;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceHigh, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          if (!compact && showToggle) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Original')),
                ButtonSegment(value: true, label: Text('Reversed')),
              ],
              selected: {state.reversed},
              onSelectionChanged: (s) => controller.setReversed(s.first),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: ClipWaveform(
              key: ValueKey(clip.path),
              peaks: clip.peaks,
              progress: state.progress,
              playedColor: accent,
              height: compact ? 72 : 100,
              onSeek: controller.seekToFraction,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Time(formatDuration(state.position)),
              _Time(formatDuration(state.duration)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showShare && compact) const SizedBox(width: 56),
              PlayPauseButton(
                playing: state.playing,
                enabled: state.loaded,
                color: accent,
                onPressed: controller.togglePlay,
              ),
              if (showShare && compact)
                Builder(
                  builder: (ctx) => IconButton(
                    tooltip: 'Share',
                    iconSize: 28,
                    constraints: const BoxConstraints.tightFor(width: 56, height: 56),
                    color: AppColors.text,
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: () =>
                        shareClip(args.pair.reversed.path, origin: originOf(ctx)),
                  ),
                ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF6B6B))),
          ],
          if (!compact) ...[
            const SizedBox(height: 8),
            _TuneSlider(
              label: 'Speed',
              value: state.speed,
              min: 0.5,
              max: 2.0,
              onChanged: controller.setSpeed,
            ),
            _TuneSlider(
              label: 'Pitch',
              value: state.pitch,
              min: 0.5,
              max: 2.0,
              onChanged: controller.setPitch,
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: controller.resetTuning,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
                const Spacer(),
                if (showShare)
                  Builder(
                    builder: (ctx) => FilledButton.icon(
                      onPressed: () => shareClip(
                        args.pair.reversed.path,
                        origin: originOf(ctx),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share reversed'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textDim,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
}

class _TuneSlider extends StatelessWidget {
  const _TuneSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 0.05).round(),
            semanticFormatterCallback: (v) => '${v.toStringAsFixed(2)}x',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(2)}x',
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.textDim,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Round play/pause button whose icon morphs between the two states.
class PlayPauseButton extends StatefulWidget {
  const PlayPauseButton({
    super.key,
    required this.playing,
    required this.onPressed,
    this.enabled = true,
    this.color = AppColors.lime,
  });

  final bool playing;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.playing ? 1 : 0,
  );

  @override
  void didUpdateWidget(PlayPauseButton old) {
    super.didUpdateWidget(old);
    if (widget.playing != old.playing) {
      widget.playing ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.playing ? 'Pause' : 'Play',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.enabled ? 1 : 0.4,
        child: Material(
          color: widget.color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.enabled ? widget.onPressed : null,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _c,
                  size: 40,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
