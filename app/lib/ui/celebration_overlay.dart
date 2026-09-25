import 'dart:math' as math;
import 'dart:ui' as ui;

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
      scheme.secondary,
      flow.success,
      scheme.tertiary,
      flow.highPriority,
      flow.mediumPriority,
    ];

    return IgnorePointer(
      key: const ValueKey('flowdo-celebration'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = _controller.value;
          // 前半段爆发，后半段缓缓收束淡出。
          final burst = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
          final hold = Curves.easeOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
          final fade = (1.0 - Curves.easeInCubic.transform(hold)).clamp(0.0, 1.0);
          final flash = (1.0 - (t / 0.22).clamp(0.0, 1.0)) * 0.22;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 轻闪，给正反馈一点「落地感」。
              ColoredBox(
                color: scheme.primary.withValues(alpha: flash),
              ),
              CustomPaint(
                painter: _CelebrationPainter(
                  burst: burst,
                  fade: fade,
                  progress: t,
                  colors: colors,
                  checkColor: scheme.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.kind,
    required this.colorIndex,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final int kind; // 0 圆点, 1 短条, 2 菱形, 3 弧片
  final int colorIndex;
  final double delay;
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
    return List.generate(48, (i) {
      return _Particle(
        angle: (math.pi * 2 / 48) * i + rng.nextDouble() * 0.35,
        speed: 0.55 + rng.nextDouble() * 0.9,
        size: 3.5 + rng.nextDouble() * 5.5,
        spin: (rng.nextDouble() - 0.5) * 4.2,
        kind: i % 4,
        colorIndex: i % 6,
        delay: rng.nextDouble() * 0.18,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final maxR = math.min(size.width, size.height) * 0.42;

    _paintRings(canvas, center, maxR);
    _paintParticles(canvas, center, maxR);
    _paintCheck(canvas, center);
  }

  void _paintRings(Canvas canvas, Offset center, double maxR) {
    for (var i = 0; i < 3; i++) {
      final local = ((burst - i * 0.12) / (1 - i * 0.12)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final radius = 18 + local * maxR * (0.55 + i * 0.18);
      final alpha = fade * (1 - local) * (0.55 - i * 0.12);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 - i * 0.6
        ..color = colors[i % colors.length].withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintParticles(Canvas canvas, Offset center, double maxR) {
    for (final p in _particles) {
      final local = ((burst - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      // 爆发外冲，再轻微下沉，像烟花落地。
      final travel = Curves.easeOutCubic.transform(local);
      final gravity = local * local * 36;
      final distance = 28 + travel * maxR * p.speed;
      final point = center +
          Offset(math.cos(p.angle), math.sin(p.angle)) * distance +
          Offset(0, gravity);
      final alpha = fade * (1 - local * 0.85).clamp(0.0, 1.0);
      final color = colors[p.colorIndex % colors.length].withValues(alpha: alpha);
      final paint = Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(p.spin * local * math.pi);

      switch (p.kind) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size * (1.15 - local * 0.35), paint);
        case 1:
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.size * 0.55;
          canvas.drawLine(
            Offset(-p.size * 1.4, 0),
            Offset(p.size * 1.4, 0),
            paint,
          );
        case 2:
          final path = Path()
            ..moveTo(0, -p.size)
            ..lineTo(p.size * 0.75, 0)
            ..lineTo(0, p.size)
            ..lineTo(-p.size * 0.75, 0)
            ..close();
          canvas.drawPath(path, paint);
        default:
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.size * 0.45;
          canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: p.size * 1.2),
            0,
            math.pi * 1.2,
            false,
            paint,
          );
      }
      canvas.restore();
    }
  }

  void _paintCheck(Canvas canvas, Offset center) {
    // 对勾弹出再稳住，和品牌图形标呼应。
    final pop = Curves.elasticOut.transform((burst / 0.85).clamp(0.0, 1.0));
    final scale = 0.35 + pop * 0.75;
    final alpha = fade * (0.55 + 0.45 * (1 - (progress - 0.55).clamp(0.0, 1.0)));
    final glow = Paint()
      ..color = checkColor.withValues(alpha: alpha * 0.18)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18);
    canvas.drawCircle(center, 34 * scale, glow);

    final stroke = Paint()
      ..color = checkColor.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final path = Path()
      ..moveTo(-14, 1)
      ..quadraticBezierTo(-6, 10, -1, 16)
      ..quadraticBezierTo(8, 2, 18, -14);
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.burst != burst ||
        oldDelegate.fade != fade ||
        oldDelegate.progress != progress ||
        oldDelegate.colors != colors ||
        oldDelegate.checkColor != checkColor;
  }
}
