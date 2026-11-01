import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Scrolling bars for the live microphone level. Newest sample on the right.
class LiveWaveform extends StatelessWidget {
  const LiveWaveform({
    super.key,
    required this.levels,
    this.active = true,
    this.height = 96,
    this.barCount = 40,
  });

  final List<double> levels;
  final bool active;
  final double height;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: active ? 'Live recording waveform' : 'Waveform idle',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarsPainter(
            values: _tail(),
            color: active ? AppColors.pink : AppColors.surfaceHigh,
          ),
        ),
      ),
    );
  }

  List<double> _tail() {
    final start = math.max(0, levels.length - barCount);
    final tail = levels.sublist(start);
    return [...List.filled(barCount - tail.length, 0.0), ...tail];
  }
}

/// A finished clip's peaks, with the played part highlighted. Tap or drag to
/// seek when [onSeek] is given.
class ClipWaveform extends StatelessWidget {
  const ClipWaveform({
    super.key,
    required this.peaks,
    required this.progress,
    this.onSeek,
    this.height = 96,
    this.playedColor = AppColors.lime,
  });

  final List<double> peaks;
  final double progress;
  final ValueChanged<double>? onSeek;
  final double height;
  final Color playedColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset p) =>
            onSeek?.call((p.dx / constraints.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null ? null : (d) => seek(d.localPosition),
          onHorizontalDragUpdate:
              onSeek == null ? null : (d) => seek(d.localPosition),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarsPainter(
                values: peaks,
                color: AppColors.textDim.withValues(alpha: 0.45),
                playedColor: playedColor,
                progress: progress,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.color,
    this.playedColor,
    this.progress = 0,
  });

  final List<double> values;
  final Color color;
  final Color? playedColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final slot = size.width / values.length;
    final barWidth = slot * 0.62;
    final paint = Paint()..strokeCap = StrokeCap.round..strokeWidth = barWidth;
    final midY = size.height / 2;
    for (var i = 0; i < values.length; i++) {
      final x = slot * i + slot / 2;
      // sqrt lifts quiet speech so the bars don't look flat.
      final h = math.max(4.0, math.sqrt(values[i].clamp(0.0, 1.0)) * size.height);
      final played = playedColor != null && (i + 0.5) / values.length <= progress;
      paint.color = played ? playedColor! : color;
      canvas.drawLine(
        Offset(x, midY - (h - barWidth) / 2),
        Offset(x, midY + (h - barWidth) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values ||
      old.progress != progress ||
      old.color != color ||
      old.playedColor != playedColor;
}
