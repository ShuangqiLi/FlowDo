import 'package:flutter/material.dart';

import '../theme.dart';

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

/// 日历加点按加减选时刻，不要转盘。取消时返回 null。
Future<ReminderPlan?> showReminderTimePicker(
  BuildContext context, {
  DateTime? initial,
  String repeat = 'ONCE',
}) {
  final now = DateTime.now();
  final start = initial != null && initial.isAfter(now)
      ? initial
      : now.add(const Duration(hours: 1));
  return showDialog<ReminderPlan>(
    context: context,
    builder: (dialogContext) {
      return _ReminderPickerDialog(
        initial: start,
        repeat: remindRepeatOrder.contains(repeat) ? repeat : 'ONCE',
      );
    },
  );
}

class _ReminderPickerDialog extends StatefulWidget {
  const _ReminderPickerDialog({
    required this.initial,
    required this.repeat,
  });

  final DateTime initial;
  final String repeat;

  @override
  State<_ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<_ReminderPickerDialog> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  late DateTime _shown;
  late DateTime _selected;
  late int _hour;
  late int _minute;
  late String _repeat;
  String? _error;

  @override
  void initState() {
    super.initState();
    final start = widget.initial;
    _shown = DateTime(start.year, start.month);
    _selected = DateTime(start.year, start.month, start.day);
    _hour = start.hour;
    _minute = start.minute;
    _repeat = widget.repeat;
  }

  DateTime get _picked => DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        _hour,
        _minute,
      );

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isPastDay(DateTime day) => day.isBefore(_today);

  void _shiftMonth(int delta) {
    final next = DateTime(_shown.year, _shown.month + delta);
    final firstAllowed = DateTime(_today.year, _today.month);
    if (next.isBefore(firstAllowed)) {
      return;
    }
    setState(() {
      _shown = next;
      _error = null;
    });
  }

  void _confirm() {
    final picked = _picked;
    if (!picked.isAfter(DateTime.now())) {
      setState(() => _error = '提醒时间要比现在晚');
      return;
    }
    Navigator.of(context).pop(ReminderPlan(at: picked, repeat: _repeat));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      title: const Text('设个提醒'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _monthHeader(context, scheme),
            const SizedBox(height: AppSpacing.xs),
            _calendar(context, scheme),
            const SizedBox(height: AppSpacing.md),
            Text('几点', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _StepField(
                    label: '时',
                    value: _hour,
                    width: 2,
                    onChanged: (value) => setState(() {
                      _hour = (value + 24) % 24;
                      _error = null;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StepField(
                    label: '分',
                    value: _minute,
                    width: 2,
                    onChanged: (value) => setState(() {
                      _minute = (value + 60) % 60;
                      _error = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('多久重复', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final item in remindRepeatOrder)
                  ChoiceChip(
                    label: Text(remindRepeatLabel(item)),
                    selected: _repeat == item,
                    onSelected: (_) => setState(() {
                      _repeat = item;
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                key: const ValueKey('reminder-time-error'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('好'),
        ),
      ],
    );
  }

  Widget _monthHeader(BuildContext context, ColorScheme scheme) {
    final canGoPrev = DateTime(_shown.year, _shown.month)
        .isAfter(DateTime(_today.year, _today.month));
    return Row(
      children: [
        IconButton(
          tooltip: '上个月',
          onPressed: canGoPrev ? () => _shiftMonth(-1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '${_shown.year}年${_shown.month}月',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          tooltip: '下个月',
          onPressed: () => _shiftMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _calendar(BuildContext context, ColorScheme scheme) {
    final first = DateTime(_shown.year, _shown.month, 1);
    final leading = (first.weekday + 6) % 7;
    final daysInMonth = DateTime(_shown.year, _shown.month + 1, 0).day;
    final cells = leading + daysInMonth;
    final rows = ((cells + 6) / 7).ceil();

    return Column(
      key: const ValueKey('reminder-calendar'),
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _dayCell(
                    context,
                    scheme,
                    index: row * 7 + col,
                    leading: leading,
                    daysInMonth: daysInMonth,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    ColorScheme scheme, {
    required int index,
    required int leading,
    required int daysInMonth,
  }) {
    final day = index - leading + 1;
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 44);
    }
    final date = DateTime(_shown.year, _shown.month, day);
    final past = _isPastDay(date);
    final selected = date == _selected;
    final isToday = date == _today;
    final ink = selected
        ? scheme.onPrimary
        : past
            ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
            : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? scheme.primary
            : isToday
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: past
              ? null
              : () => setState(() {
                    _selected = date;
                    _error = null;
                  }),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                '$day',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: ink,
                      fontWeight: selected || isToday
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepField extends StatelessWidget {
  const _StepField({
    required this.label,
    required this.value,
    required this.width,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int width;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      value: value.toString().padLeft(width, '0'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '减少$label',
              onPressed: () => onChanged(value - 1),
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    value.toString().padLeft(width, '0'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '增加$label',
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
