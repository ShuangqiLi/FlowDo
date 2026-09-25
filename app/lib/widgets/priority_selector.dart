import 'package:flutter/material.dart';

import '../theme.dart';

const priorityOrder = ['HIGH', 'MEDIUM', 'LOW'];

Color priorityColor(BuildContext context, String priority) {
  return context.flowColors.priority(priority);
}

String priorityLabel(String priority) {
  return switch (priority) {
    'HIGH' => '高',
    'LOW' => '低',
    _ => '中',
  };
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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
          child: Text(
            priorityLabel(priority),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
