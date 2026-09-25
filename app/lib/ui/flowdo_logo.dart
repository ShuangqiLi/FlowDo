import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 品牌图形标：一个柔和收笔的对勾。
class FlowDoLogo extends StatelessWidget {
  const FlowDoLogo({
    super.key,
    this.size = 64,
    this.withBackground = true,
    this.color,
  });

  final double size;
  final bool withBackground;

  /// 单色场景下的描边色，留空则跟随当前主题。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final mark = Semantics(
      label: 'FlowDo',
      image: true,
      child: SizedBox.square(
        dimension: size * 0.62,
        child: CustomPaint(
          painter: _FlowMarkPainter(stroke: color ?? scheme.primary),
        ),
      ),
    );
    if (!withBackground) return mark;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: mark,
    );
  }
}

class _FlowMarkPainter extends CustomPainter {
  const _FlowMarkPainter({required this.stroke});

  final Color stroke;

  /// 设计稿坐标系为 512×512，描边 56 宽、圆头圆角，
  /// 与 assets/branding/flowdo_mark.svg 保持一致。
  static const double _designStroke = 56;

  static Path _checkMark() => Path()
    ..moveTo(124, 262)
    ..cubicTo(154, 296, 184, 326, 210, 352)
    ..cubicTo(256, 300, 320, 226, 388, 148);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final checkMark = _checkMark();
    final bounds = checkMark.getBounds().inflate(_designStroke / 2);
    final scale = math.min(size.width / bounds.width, size.height / bounds.height);

    canvas.save();
    canvas.translate(
      (size.width - bounds.width * scale) / 2,
      (size.height - bounds.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _designStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = stroke;
    canvas.drawPath(checkMark, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowMarkPainter oldDelegate) => oldDelegate.stroke != stroke;
}

class FlowDoBrand extends StatelessWidget {
  const FlowDoBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlowDoLogo(size: compact ? 36 : 46),
        const SizedBox(width: AppSpacing.sm),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '随随办办',
              style: (compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(fontFamily: 'ZCOOLKuaiLe'),
            ),
            Text(
              'FlowDo',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
