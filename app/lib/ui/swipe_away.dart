import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 右滑跟手离开；不够远或不够快就弹回。往左滑过头也有一点回弹。
class SwipeAway extends StatefulWidget {
  const SwipeAway({
    super.key,
    required this.onAway,
    required this.child,
    this.fromLeftEdgeOnly = false,
    this.edgeWidth = 56,
  });

  final VoidCallback onAway;
  final Widget child;

  /// 为 true 时只从左缘起势，避免和任务卡片左右滑抢手势。
  final bool fromLeftEdgeOnly;
  final double edgeWidth;

  @override
  State<SwipeAway> createState() => _SwipeAwayState();
}

class _SwipeAwayState extends State<SwipeAway> {
  double _dragX = 0;
  bool _dragging = false;
  bool _armed = false;

  void _reset() {
    if (!mounted) {
      return;
    }
    setState(() {
      _dragging = false;
      _armed = false;
      _dragX = 0;
    });
  }

  void _onDragStart(DragStartDetails details) {
    final armed = !widget.fromLeftEdgeOnly ||
        details.localPosition.dx <= widget.edgeWidth;
    setState(() {
      _dragging = true;
      _armed = armed;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_armed) {
      return;
    }
    setState(() {
      final next = _dragX + details.delta.dx;
      // 往左没有退路：轻阻力跟手，松手弹回。
      _dragX = next < 0 ? next * 0.28 : next;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_armed) {
      _reset();
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragX > 0 && (velocity > 700 || _dragX > width * 0.3)) {
      widget.onAway();
      return;
    }
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final offsetX = width == 0 ? 0.0 : _dragX / width;

    final slid = AnimatedSlide(
      offset: Offset(offsetX, 0),
      duration: _dragging ? Duration.zero : AppMotion.quick,
      curve: AppMotion.curve,
      child: widget.child,
    );

    if (!widget.fromLeftEdgeOnly) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _reset,
        child: slid,
      );
    }

    // 左缘热区：拖动开始后随手指放宽，避免滑一半丢手势。
    final hotWidth = math.max(widget.edgeWidth, _armed ? _dragX + widget.edgeWidth : widget.edgeWidth);

    return Stack(
      fit: StackFit.expand,
      children: [
        slid,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: hotWidth.clamp(widget.edgeWidth, width),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: _reset,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

/// 右滑返回上一页。
class SwipeToPop extends StatelessWidget {
  const SwipeToPop({
    super.key,
    required this.child,
    this.fromLeftEdgeOnly = true,
  });

  final Widget child;
  final bool fromLeftEdgeOnly;

  @override
  Widget build(BuildContext context) {
    return SwipeAway(
      fromLeftEdgeOnly: fromLeftEdgeOnly,
      onAway: () {
        Navigator.of(context).maybePop();
      },
      child: child,
    );
  }
}
