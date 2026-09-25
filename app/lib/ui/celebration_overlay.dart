import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

void showFlowDoCelebration(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationOverlay(onFinished: entry.remove),
  );
  overlay.insert(entry);
}

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.celebration,
  )..forward().whenComplete(widget.onFinished);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      key: const ValueKey('flowdo-celebration'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _CelebrationPainter(
            progress: Curves.easeOutCubic.transform(_controller.value),
            colors: [
              scheme.primary,
              scheme.secondary,
              context.flowColors.success,
              scheme.tertiary,
            ],
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var i = 0; i < 14; i++) {
      final angle = (math.pi * 2 / 14) * i - math.pi / 2;
      final distance = 24 + progress * (70 + (i % 3) * 12);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: fade)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = i.isEven ? 6 : 4;
      if (i.isEven) {
        canvas.drawCircle(point, 3.5 + (1 - progress) * 2, paint);
      } else {
        final tangent = Offset(-math.sin(angle), math.cos(angle)) * 7;
        canvas.drawLine(point - tangent, point + tangent, paint);
      }
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colors.first.withValues(alpha: fade * 0.7);
    canvas.drawCircle(center, 16 + progress * 20, ring);
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
  }
}
