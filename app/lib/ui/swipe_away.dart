import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';

/// 右滑跟手离开；不够远或不够快就弹回。往左滑过头也有一点回弹。
class SwipeAway extends StatefulWidget {
  const SwipeAway({
    super.key,
    required this.onAway,
    required this.child,
    this.fromLeftEdgeOnly = false,
    this.avoidHorizontalScrollers = false,
    this.edgeWidth = 56,
  });

  final VoidCallback onAway;
  final Widget child;

  /// 为 true 时只从左缘起势，避免和任务卡片左右滑抢手势。
  final bool fromLeftEdgeOnly;

  /// 起点落在横向翻页上时不参加，留给月历自己滑。
  final bool avoidHorizontalScrollers;
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
    if (_pointerOnEditable(details.globalPosition)) {
      setState(() {
        _dragging = false;
        _armed = false;
      });
      return;
    }
    final armed = !widget.fromLeftEdgeOnly ||
        details.localPosition.dx <= widget.edgeWidth;
    setState(() {
      _dragging = true;
      _armed = armed;
    });
  }

  /// 按下时就落在输入框或横向翻页上：这次手势不参加竞争。
  bool _allowsSwipe(Offset global) {
    if (_pointerOnEditable(global)) {
      return false;
    }
    if (widget.avoidHorizontalScrollers && _onHorizontalScrollable(global)) {
      return false;
    }
    return true;
  }

  bool _onHorizontalScrollable(Offset global) {
    var found = false;
    void visitor(Element element) {
      if (found) {
        return;
      }
      final widget = element.widget;
      if (widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.horizontal) {
        final render = element.renderObject;
        if (render is RenderBox && render.attached && render.hasSize) {
          final rect = render.localToGlobal(Offset.zero) & render.size;
          if (rect.contains(global)) {
            found = true;
            return;
          }
        }
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return found;
  }

  /// 起点落在输入框就别抢手势，好让选字和框内滑动。
  bool _pointerOnEditable(Offset global) {
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(result, global, View.of(context).viewId);
    for (final entry in result.path) {
      if (entry.target is RenderEditable) {
        return true;
      }
    }
    return _hitEditable(global);
  }

  bool _hitEditable(Offset global) {
    bool found = false;
    void visitor(Element element) {
      if (found) {
        return;
      }
      if (element.widget is EditableText || element.widget is TextField) {
        final render = element.renderObject;
        if (render is RenderBox && render.hasSize) {
          final topLeft = render.localToGlobal(Offset.zero);
          final rect = topLeft & render.size;
          if (rect.contains(global)) {
            found = true;
            return;
          }
        }
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return found;
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
      return _swipeRecognizer(
        behavior: HitTestBehavior.opaque,
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
          child: _swipeRecognizer(
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _swipeRecognizer({
    required HitTestBehavior behavior,
    required Widget child,
  }) {
    return RawGestureDetector(
      behavior: behavior,
      gestures: {
        _BlankAreaDrag: GestureRecognizerFactoryWithHandlers<_BlankAreaDrag>(
          () => _BlankAreaDrag(allows: _allowsSwipe),
          (instance) {
            instance
              ..onStart = _onDragStart
              ..onUpdate = _onDragUpdate
              ..onEnd = _onDragEnd
              ..onCancel = _reset;
          },
        ),
      },
      child: child,
    );
  }
}

/// 落在输入框上的按下不加入滑动竞技，避免抢走选字。
class _BlankAreaDrag extends HorizontalDragGestureRecognizer {
  _BlankAreaDrag({required this.allows});

  final bool Function(Offset global) allows;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!allows(event.position)) {
      return;
    }
    super.addAllowedPointer(event);
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
