import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The big central record button: pulses while recording, morphs from a circle
/// to a rounded square, and draws a progress ring toward the time limit.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.recording,
    required this.busy,
    required this.progress,
    required this.onPressed,
  });

  final bool recording;
  final bool busy;

  /// 0..1 share of the maximum recording time used.
  final double progress;
  final VoidCallback onPressed;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  static const double _size = 240;
  static const double _core = 132;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.recording) _pulse.repeat();
  }

  @override
  void didUpdateWidget(RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !widget.busy,
      label: widget.recording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTapDown: widget.busy ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.busy ? null : widget.onPressed,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  size: const Size(_size, _size),
                  painter: _RingPainter(
                    t: _pulse.value,
                    recording: widget.recording,
                    progress: widget.progress,
                    coreRadius: _core / 2,
                  ),
                ),
              ),
              AnimatedScale(
                scale: _pressed ? 0.92 : 1,
                duration: const Duration(milliseconds: 120),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  width: _core,
                  height: _core,
                  decoration: BoxDecoration(
                    color: widget.busy ? AppColors.surfaceHigh : AppColors.pink,
                    borderRadius:
                        BorderRadius.circular(widget.recording ? 36 : _core / 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink
                            .withValues(alpha: widget.recording ? 0.55 : 0.35),
                        blurRadius: widget.recording ? 40 : 24,
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.busy
                        ? const Padding(
                            key: ValueKey('busy'),
                            padding: EdgeInsets.all(44),
                            child: CircularProgressIndicator(
                              strokeWidth: 5,
                              color: AppColors.lime,
                            ),
                          )
                        : Icon(
                            widget.recording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            key: ValueKey(widget.recording),
                            size: 64,
                            color: Colors.black,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.t,
    required this.recording,
    required this.progress,
    required this.coreRadius,
  });

  final double t;
  final bool recording;
  final double progress;
  final double coreRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ringRadius = coreRadius + 24;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = AppColors.surfaceHigh;
    canvas.drawCircle(c, ringRadius, track);

    if (recording) {
      for (final offset in [0.0, 0.5]) {
        final phase = (t + offset) % 1;
        canvas.drawCircle(
          c,
          coreRadius + phase * 50,
          Paint()..color = AppColors.pink.withValues(alpha: (1 - phase) * 0.3),
        );
      }
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ringRadius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = AppColors.lime,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.recording != recording || old.progress != progress;
}
