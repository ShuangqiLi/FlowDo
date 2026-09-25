import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';
import 'task_gesture_policy.dart';

/// 仅左右滑归类 / 删除。成功离场时淡出，取消时弹回并淡回。
class TaskInteractable extends StatefulWidget {
  const TaskInteractable({
    super.key,
    required this.task,
    required this.child,
    this.onSwipeTo,
    this.onDelete,
  });

  final Task task;
  final Widget child;
  final ValueChanged<String>? onSwipeTo;
  final Future<void> Function()? onDelete;

  @override
  State<TaskInteractable> createState() => _TaskInteractableState();
}

class _TaskInteractableState extends State<TaskInteractable>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  double _opacity = 1;
  late final AnimationController _motion;

  TaskSwipeHint? get _right =>
      TaskGesturePolicy.swipeRight(widget.task.status);
  TaskSwipeHint? get _left => TaskGesturePolicy.swipeLeft(widget.task.status);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: AppMotion.standard);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _motion.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    var next = _dx + details.delta.dx;
    if (next > 0 && _right == null) {
      next *= 0.28;
    }
    if (next < 0 && _left == null) {
      next *= 0.28;
    }
    final width = context.size?.width ?? 320;
    final fade = (1 - (next.abs() / width) * 0.45).clamp(0.45, 1.0);
    setState(() {
      _dx = next;
      _opacity = fade;
    });
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final width = context.size?.width ?? 320;
    final threshold = width * 0.32;
    final velocity = details.primaryVelocity ?? 0;
    String? target;
    if ((_dx > threshold || velocity > 700) && _right != null) {
      target = _right!.status;
    } else if ((_dx < -threshold || velocity < -700) && _left != null) {
      target = _left!.status;
    }
    if (target == null) {
      await _animateTo(dx: 0, opacity: 1);
      return;
    }
    if (target == 'DELETE') {
      await widget.onDelete?.call();
      if (mounted) {
        await _animateTo(dx: 0, opacity: 1);
      }
      return;
    }
    final endDx = target == _right?.status ? width : -width;
    await _animateTo(dx: endDx, opacity: 0);
    if (!mounted) {
      return;
    }
    widget.onSwipeTo?.call(target);
  }

  Future<void> _animateTo({required double dx, required double opacity}) async {
    final startDx = _dx;
    final startOpacity = _opacity;
    _motion.reset();
    void listener() {
      final t = AppMotion.curve.transform(_motion.value);
      setState(() {
        _dx = startDx + (dx - startDx) * t;
        _opacity = startOpacity + (opacity - startOpacity) * t;
      });
    }

    _motion.addListener(listener);
    await _motion.forward();
    _motion.removeListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_right == null && _left == null) {
      return widget.child;
    }

    return RawGestureDetector(
      gestures: {
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
          (instance) {
            instance.onStart = _onDragStart;
            instance.onUpdate = _onDragUpdate;
            instance.onEnd = _onDragEnd;
          },
        ),
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: (_dx.abs() / 48).clamp(0.0, 1.0),
                child: ColoredBox(
                  color: _dx >= 0
                      ? scheme.primary.withValues(alpha: 0.16)
                      : _left?.status == 'DELETE'
                          ? scheme.error.withValues(alpha: 0.16)
                          : scheme.secondaryContainer,
                  child: Align(
                    alignment: _dx >= 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Icon(
                        _dx >= 0
                            ? (_right?.icon ?? Icons.block_rounded)
                            : (_left?.icon ?? Icons.block_rounded),
                        color: _dx >= 0
                            ? scheme.primary
                            : _left?.status == 'DELETE'
                                ? scheme.error
                                : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_dx, 0),
              child: Opacity(
                opacity: _opacity,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
