import 'package:flutter/material.dart';

class TaskSwipeHint {
  const TaskSwipeHint({
    required this.status,
    required this.icon,
    required this.label,
  });

  final String status;
  final IconData icon;
  final String label;
}

/// 全平台同一套左右滑规则。
abstract final class TaskGesturePolicy {
  static TaskSwipeHint? swipeRight(String status) {
    return switch (status) {
      'TODO' => const TaskSwipeHint(
          status: 'FOCUS',
          icon: Icons.center_focus_strong_rounded,
          label: '聚焦',
        ),
      'FOCUS' => const TaskSwipeHint(
          status: 'DONE',
          icon: Icons.check_circle_rounded,
          label: '完成',
        ),
      _ => null,
    };
  }

  static TaskSwipeHint? swipeLeft(String status) {
    return switch (status) {
      'TODO' => const TaskSwipeHint(
          status: 'DELETE',
          icon: Icons.delete_outline_rounded,
          label: '删除',
        ),
      'FOCUS' => const TaskSwipeHint(
          status: 'TODO',
          icon: Icons.inbox_rounded,
          label: '任务池',
        ),
      'DONE' => const TaskSwipeHint(
          status: 'TODO',
          icon: Icons.inbox_rounded,
          label: '任务池',
        ),
      _ => null,
    };
  }
}
