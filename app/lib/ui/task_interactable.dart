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
  final _dx = ValueNotifier<double>(0);
  final _opacity = ValueNotifier<double>(1);
  late final AnimationController _motion;
  late final Listenable _tick;

  TaskSwipeHint? get _right =>
      TaskGesturePolicy.swipeRight(widget.task.status);
  TaskSwipeHint? get _left => TaskGesturePolicy.swipeLeft(widget.task.status);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: AppMotion.standard);
    _tick = Listenable.merge([_dx, _opacity]);
  }

  @override
  void dispose() {
    _motion.dispose();
    _dx.dispose();
    _opacity.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    var next = _dx.value + details.delta.dx;
    if (next > 0 && _right == null) {
      next *= 0.28;
    }
    if (next < 0 && _left == null) {
      next *= 0.28;
    }
    final width = context.size?.width ?? 320;
    _dx.value = next;
    _opacity.value = (1 - (next.abs() / width) * 0.45).clamp(0.45, 1.0);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final width = context.size?.width ?? 320;
    final threshold = width * 0.32;
    final velocity = details.primaryVelocity ?? 0;
    String? target;
    if ((_dx.value > threshold || velocity > 700) && _right != null) {
      target = _right!.status;
    } else if ((_dx.value < -threshold || velocity < -700) && _left != null) {
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
    final startDx = _dx.value;
    final startOpacity = _opacity.value;
    _motion.reset();
    void listener() {
      final t = AppMotion.curve.transform(_motion.value);
      _dx.value = startDx + (dx - startDx) * t;
      _opacity.value = startOpacity + (opacity - startOpacity) * t;
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

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.deferToChild,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: AnimatedBuilder(
          animation: _tick,
          builder: (context, child) {
            final dx = _dx.value;
            return Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: (dx.abs() / 48).clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: dx >= 0
                          ? scheme.primary.withValues(alpha: 0.16)
                          : _left?.status == 'DELETE'
                              ? scheme.error.withValues(alpha: 0.16)
                              : scheme.secondaryContainer,
                      child: Align(
                        alignment:
                            dx >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Icon(
                            dx >= 0
                                ? (_right?.icon ?? Icons.block_rounded)
                                : (_left?.icon ?? Icons.block_rounded),
                            color: dx >= 0
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
                  offset: Offset(dx, 0),
                  child: Opacity(
                    opacity: _opacity.value,
                    child: child,
                  ),
                ),
              ],
            );
          },
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}
