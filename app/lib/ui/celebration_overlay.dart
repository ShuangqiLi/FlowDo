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
    final flow = context.flowColors;
    final colors = [
      scheme.primary,
      flow.success,
      flow.mediumPriority,
      scheme.secondary,
    ];

    return IgnorePointer(
      key: const ValueKey('flowdo-celebration'),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = _controller.value;
            final burst =
                Curves.easeOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
            final fade = (1.0 -
                    Curves.easeIn.transform(((t - 0.4) / 0.6).clamp(0.0, 1.0)))
                .clamp(0.0, 1.0);

            return CustomPaint(
              painter: _CelebrationPainter(
                burst: burst,
                fade: fade,
                progress: t,
                colors: colors,
                checkColor: scheme.primary,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.colorIndex,
    required this.delay,
    required this.kind,
  });

  final double angle;
  final double speed;
  final double size;
  final int colorIndex;
  final double delay;
  /// 0 圆点, 1 短条, 2 菱形
  final int kind;
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({
    required this.burst,
    required this.fade,
    required this.progress,
    required this.colors,
    required this.checkColor,
  });

  final double burst;
  final double fade;
  final double progress;
  final List<Color> colors;
  final Color checkColor;

  static final List<_Particle> _particles = _buildParticles();

  static List<_Particle> _buildParticles() {
    final rng = math.Random(42);
    return List.generate(32, (i) {
      return _Particle(
        angle: (math.pi * 2 / 32) * i + rng.nextDouble() * 0.3,
        speed: 0.55 + rng.nextDouble() * 0.8,
        size: 2.8 + rng.nextDouble() * 3.8,
        colorIndex: i % 4,
        delay: rng.nextDouble() * 0.16,
        kind: i % 3,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final maxR = math.min(size.width, size.height) * 0.38;

    _paintRings(canvas, center, maxR);
    _paintParticles(canvas, center, maxR);
    _paintCheck(canvas, center);
  }

  void _paintRings(Canvas canvas, Offset center, double maxR) {
    final paint = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < 2; i++) {
      final local = ((burst - i * 0.12) / (1 - i * 0.12)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      paint
        ..strokeWidth = 2.6 - i * 0.5
        ..color = colors[i % colors.length]
            .withValues(alpha: fade * (1 - local) * (0.5 - i * 0.12));
      canvas.drawCircle(center, 18 + local * maxR * (0.62 + i * 0.16), paint);
    }
  }

  void _paintParticles(Canvas canvas, Offset center, double maxR) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final p in _particles) {
      final local = ((burst - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final travel = Curves.easeOutCubic.transform(local);
      final distance = 24 + travel * maxR * p.speed;
      final point = center +
          Offset(math.cos(p.angle), math.sin(p.angle)) * distance +
          Offset(0, local * local * 28);
      final alpha = fade * (1 - local * 0.85).clamp(0.0, 1.0);
      paint.color = colors[p.colorIndex].withValues(alpha: alpha);
      switch (p.kind) {
        case 0:
          paint.style = PaintingStyle.fill;
          canvas.drawCircle(point, p.size * (1.1 - local * 0.3), paint);
        case 1:
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.size * 0.5;
          final dir = Offset(math.cos(p.angle), math.sin(p.angle));
          canvas.drawLine(point - dir * p.size, point + dir * p.size, paint);
        default:
          paint.style = PaintingStyle.fill;
          final s = p.size * (1.05 - local * 0.25);
          final diamond = Path()
            ..moveTo(point.dx, point.dy - s)
            ..lineTo(point.dx + s * 0.7, point.dy)
            ..lineTo(point.dx, point.dy + s)
            ..lineTo(point.dx - s * 0.7, point.dy)
            ..close();
          canvas.drawPath(diamond, paint);
      }
    }
  }

  void _paintCheck(Canvas canvas, Offset center) {
    final pop = Curves.easeOutBack.transform((burst / 0.8).clamp(0.0, 1.0));
    final scale = 0.4 + pop * 0.65;
    final alpha =
        fade * (0.6 + 0.4 * (1 - (progress - 0.5).clamp(0.0, 1.0)));

    final stroke = Paint()
      ..color = checkColor.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final path = Path()
      ..moveTo(-14, 1)
      ..lineTo(-1, 14)
      ..lineTo(18, -12);
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.burst != burst ||
        oldDelegate.fade != fade ||
        oldDelegate.progress != progress;
  }
}
