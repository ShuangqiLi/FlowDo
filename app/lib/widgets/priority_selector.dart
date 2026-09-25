import 'package:flutter/material.dart';

const priorityOrder = ['HIGH', 'MEDIUM', 'LOW'];

Color priorityColor(String priority) {
  return switch (priority) {
    'HIGH' => const Color(0xFFD64545),
    'LOW' => const Color(0xFF6B7C85),
    _ => const Color(0xFFE08A2C),
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
        final color = priorityColor(p);
        return ChoiceChip(
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
    final color = priorityColor(priority);
    return Container(
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
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
