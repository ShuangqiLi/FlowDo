import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 品牌图形标：一个柔和收笔的对勾。
class FlowDoLogo extends StatelessWidget {
  const FlowDoLogo({
    super.key,
    this.size = 64,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final mark = Semantics(
      label: 'FlowDo',
      image: true,
      child: SizedBox.square(
        dimension: size * 0.62,
        child: CustomPaint(
          painter: _FlowMarkPainter(stroke: scheme.primary),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: scheme.outlineVariant),
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
