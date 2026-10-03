import 'package:flutter/material.dart';

import '../theme.dart';

const priorityOrder = ['HIGH', 'MEDIUM', 'LOW', 'NONE', 'REMINDER'];

Color priorityColor(BuildContext context, String priority) {
  final scheme = Theme.of(context).colorScheme;
  return switch (priority) {
    'NONE' => scheme.onSurfaceVariant,
    'REMINDER' => scheme.primary,
    _ => context.flowColors.priority(priority),
  };
}

String priorityLabel(String priority) {
  return switch (priority) {
    'HIGH' => '高',
    'MEDIUM' => '中',
    'LOW' => '低',
    'REMINDER' => '提醒',
    _ => '无',
  };
}

class ReminderPlan {
  const ReminderPlan({required this.at, required this.repeat});

  final DateTime at;

  /// ONCE、DAILY、WEEKLY、MONTHLY、YEARLY。
  final String repeat;
}

const remindRepeatOrder = ['ONCE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'];

String remindRepeatLabel(String repeat) {
  return switch (repeat) {
    'DAILY' => '每天',
    'WEEKLY' => '每周',
    'MONTHLY' => '每月',
    'YEARLY' => '每年',
    _ => '仅一次',
  };
}

/// 选一个比现在晚的分钟，以及是否按天/周/月/年重复。取消时返回 null。
Future<ReminderPlan?> showReminderTimePicker(
  BuildContext context, {
  DateTime? initial,
  String repeat = 'ONCE',
}) async {
  final now = DateTime.now();
  final start = initial != null && initial.isAfter(now)
      ? initial
      : now.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime(start.year, start.month, start.day),
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(now.year + 5),
    helpText: '提醒哪一天',
    cancelText: '取消',
    confirmText: '好',
  );
  if (date == null || !context.mounted) {
    return null;
  }
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
    helpText: '提醒的时刻',
    cancelText: '取消',
    confirmText: '好',
  );
  if (time == null || !context.mounted) {
    return null;
  }
  final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (!picked.isAfter(DateTime.now())) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('提醒时间要比现在晚')),
    );
    return null;
  }
  if (!context.mounted) {
    return null;
  }
  final chosen = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('多久重复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in remindRepeatOrder)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                title: Text(remindRepeatLabel(item)),
                trailing: item == repeat
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(dialogContext).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(dialogContext).pop(item),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
  if (chosen == null) {
    return null;
  }
  return ReminderPlan(at: picked, repeat: chosen);
}

/// 贴着被点的优先级图标弹出的小菜单。
///
/// [anchorContext] 要来自图标本身，菜单按它的位置定位，而不是铺满整屏。
Future<String?> showPriorityPicker(
  BuildContext anchorContext, {
  required String current,
}) {
  final anchor = anchorContext.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
  if (anchor == null || overlay == null || !anchor.hasSize) {
    return Future<String?>.value();
  }

  final theme = Theme.of(anchorContext);
  final scheme = theme.colorScheme;
  final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = anchor.localToGlobal(
    anchor.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );

  return showMenu<String>(
    context: anchorContext,
    position: RelativeRect.fromLTRB(
      topLeft.dx,
      bottomRight.dy + AppSpacing.xxs,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    ),
    constraints: const BoxConstraints(minWidth: 132, maxWidth: 180),
    color: theme.cardColor,
    surfaceTintColor: Colors.transparent,
    elevation: 3,
    shadowColor: scheme.shadow.withValues(alpha: 0.16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.large),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    popUpAnimationStyle: AnimationStyle(
      duration: AppMotion.quick,
      curve: AppMotion.curve,
    ),
    items: [
      for (final p in priorityOrder)
        PopupMenuItem<String>(
          value: p,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: _PriorityMenuRow(priority: p, selected: p == current),
        ),
    ],
  );
}

class _PriorityMenuRow extends StatelessWidget {
  const _PriorityMenuRow({required this.priority, required this.selected});

  final String priority;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = priorityColor(context, priority);

    return Row(
      children: [
        _PriorityMark(priority: priority, color: color, compact: true),
        const SizedBox(width: AppSpacing.sm),
        Text(
          priorityLabel(priority),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: selected ? color : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
        const Spacer(),
        if (selected) Icon(Icons.check_rounded, size: 18, color: color),
      ],
    );
  }
}

/// Compact badge for list rows. Tap handling is left to the parent.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({
    super.key,
    required this.priority,
  });

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(context, priority);
    return Semantics(
      label: '${priorityLabel(priority)}优先级',
      child: ExcludeSemantics(
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: _PriorityMark(priority: priority, color: color),
        ),
      ),
    );
  }
}

class _PriorityMark extends StatelessWidget {
  const _PriorityMark({
    required this.priority,
    required this.color,
    this.compact = false,
  });

  final String priority;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (priority == 'NONE') {
      return Container(
        key: const ValueKey('priority-none-mark'),
        width: compact ? 10 : 14,
        height: 2,
        color: color,
      );
    }
    if (priority == 'REMINDER') {
      return Icon(
        Icons.flag_rounded,
        size: compact ? 14 : 16,
        color: color,
      );
    }
    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Text(
      priorityLabel(priority),
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}
