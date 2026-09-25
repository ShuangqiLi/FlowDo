import 'package:flutter/material.dart';

import '../theme.dart';

const priorityOrder = ['HIGH', 'MEDIUM', 'LOW'];

Color priorityColor(BuildContext context, String priority) {
  return context.flowColors.priority(priority);
}

IconData priorityIcon(String priority) {
  return switch (priority) {
    'HIGH' => Icons.keyboard_double_arrow_up_rounded,
    'LOW' => Icons.keyboard_arrow_down_rounded,
    _ => Icons.remove_rounded,
  };
}

String priorityLabel(String priority) {
  return switch (priority) {
    'HIGH' => '高',
    'LOW' => '低',
    _ => '中',
  };
}

Future<String?> showPriorityPicker(
  BuildContext context, {
  required String current,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('挑个优先级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in priorityOrder)
              ListTile(
                leading: PriorityBadge(priority: p),
                title: Text(priorityLabel(p)),
                trailing: p == current
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(p),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

/// Three-way chip selector for create / detail screens.
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: priorityOrder.map((p) {
        final selected = p == value;
        final color = priorityColor(context, p);
        return ChoiceChip(
          avatar: Icon(priorityIcon(p), size: 16, color: color),
          label: Text(priorityLabel(p)),
          selected: selected,
          onSelected: (_) => onChanged(p),
          selectedColor: color.withValues(alpha: 0.22),
          labelStyle: TextStyle(
            color: selected ? color : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
          ),
          showCheckmark: false,
        );
      }).toList(),
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
          child: Icon(
            priorityIcon(priority),
            color: color,
            size: 19,
          ),
        ),
      ),
    );
  }
}
