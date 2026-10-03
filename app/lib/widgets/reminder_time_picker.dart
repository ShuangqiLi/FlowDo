import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../utils/cron.dart';
import '../utils/lunar.dart';

class ReminderPlan {
  const ReminderPlan({
    required this.at,
    required this.repeat,
    this.cron,
    this.lunar = false,
  });

  final DateTime at;

  /// ONCE、DAILY、WEEKLY、MONTHLY、YEARLY、CRON。
  final String repeat;
  final String? cron;
  final bool lunar;
}

const remindRepeatOrder = [
  'ONCE',
  'DAILY',
  'WEEKLY',
  'MONTHLY',
  'YEARLY',
  'CRON',
];

String remindRepeatLabel(String repeat) {
  return switch (repeat) {
    'DAILY' => '每天',
    'WEEKLY' => '每周',
    'MONTHLY' => '每月',
    'YEARLY' => '每年',
    'CRON' => 'crontab',
    _ => '仅一次',
  };
}

/// 卡片和详情上的提醒时刻。仅一次不写「提醒」；勾了农历就用农历日期。
String reminderWhenText(
  DateTime at, {
  required bool lunar,
  bool withYear = false,
}) {
  final local = at.toLocal();
  final clock = DateFormat('HH:mm').format(local);
  if (lunar) {
    final name = lunarCellLabel(local.year, local.month, local.day);
    if (name.isNotEmpty) {
      return '农历$name $clock';
    }
  }
  final pattern = withYear ? 'yyyy年M月d日' : 'M月d日';
  return '${DateFormat(pattern).format(local)} $clock';
}

bool remindRepeatUsesLunar(String repeat) {
  return repeat == 'ONCE' || repeat == 'MONTHLY' || repeat == 'YEARLY';
}

/// 日历加点按加减选时刻，也可以点数字用键盘输入。取消时返回 null。
Future<ReminderPlan?> showReminderTimePicker(
  BuildContext context, {
  DateTime? initial,
  String repeat = 'ONCE',
  String? cron,
  bool lunar = false,
}) {
  final now = DateTime.now();
  final localInitial = initial?.toLocal();
  final start = localInitial != null && localInitial.isAfter(now)
      ? localInitial
      : now.add(const Duration(hours: 1));
  return showDialog<ReminderPlan>(
    context: context,
    builder: (dialogContext) {
      return _ReminderPickerDialog(
        initial: start,
        repeat: remindRepeatOrder.contains(repeat) ? repeat : 'ONCE',
        cron: cron,
        lunar: lunar,
      );
    },
  );
}

class _ReminderPickerDialog extends StatefulWidget {
  const _ReminderPickerDialog({
    required this.initial,
    required this.repeat,
    this.cron,
    this.lunar = false,
  });

  final DateTime initial;
  final String repeat;
  final String? cron;
  final bool lunar;

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
  late bool _lunar;
  late final TextEditingController _cron;
  String? _error;
  final _hourField = GlobalKey<_StepFieldState>();
  final _minuteField = GlobalKey<_StepFieldState>();

  @override
  void initState() {
    super.initState();
    final start = widget.initial;
    _shown = DateTime(start.year, start.month);
    _selected = DateTime(start.year, start.month, start.day);
    _hour = start.hour;
    _minute = start.minute;
    _repeat = widget.repeat;
    _lunar = widget.lunar && remindRepeatUsesLunar(widget.repeat);
    _cron = TextEditingController(text: widget.cron ?? '0 9 * * *');
  }

  @override
  void dispose() {
    _cron.dispose();
    super.dispose();
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

  bool get _isCron => _repeat == 'CRON';

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
    if (_isCron) {
      try {
        final expr = normalizeCron(_cron.text);
        final next = nextCronOccurrence(expr, DateTime.now());
        Navigator.of(context).pop(
          ReminderPlan(at: next, repeat: 'CRON', cron: expr),
        );
      } on CronParseException catch (error) {
        setState(() => _error = error.message);
      }
      return;
    }
    final hourOk = _hourField.currentState?.commit() ?? true;
    final minuteOk = _minuteField.currentState?.commit() ?? true;
    if (!hourOk || !minuteOk) {
      setState(() {
        _error = !hourOk ? '小时是 0 到 23' : '分钟是 0 到 59';
      });
      return;
    }
    final picked = _picked;
    if (!picked.isAfter(DateTime.now())) {
      setState(() => _error = '提醒时间要比现在晚');
      return;
    }
    Navigator.of(context).pop(
      ReminderPlan(
        at: picked,
        repeat: _repeat,
        lunar: _lunar && remindRepeatUsesLunar(_repeat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lunarLabel = lunarCellLabel(
      _selected.year,
      _selected.month,
      _selected.day,
    );
    return AlertDialog(
      scrollable: true,
      title: const Text('设个提醒'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isCron) ...[
              _monthHeader(context, scheme),
              const SizedBox(height: AppSpacing.xs),
              _calendar(context, scheme),
              if (_lunar && lunarLabel.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '农历$lunarLabel',
                  key: const ValueKey('reminder-lunar-label'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('几点', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _StepField(
                      key: _hourField,
                      label: '时',
                      value: _hour,
                      max: 23,
                      fieldKey: const ValueKey('reminder-hour-field'),
                      onChanged: (value) => setState(() {
                        _hour = value;
                        _error = null;
                      }),
                      onInvalid: (message) => setState(() => _error = message),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StepField(
                      key: _minuteField,
                      label: '分',
                      value: _minute,
                      max: 59,
                      fieldKey: const ValueKey('reminder-minute-field'),
                      onChanged: (value) => setState(() {
                        _minute = value;
                        _error = null;
                      }),
                      onInvalid: (message) => setState(() => _error = message),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
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
                      if (!remindRepeatUsesLunar(item)) {
                        _lunar = false;
                      }
                      _error = null;
                    }),
                  ),
                if (remindRepeatUsesLunar(_repeat))
                  FilterChip(
                    key: const ValueKey('reminder-lunar-chip'),
                    label: const Text('农历'),
                    selected: _lunar,
                    onSelected: (selected) => setState(() {
                      _lunar = selected;
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_isCron) ...[
              const SizedBox(height: AppSpacing.md),
              Text('crontab', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: const ValueKey('reminder-cron-field'),
                controller: _cron,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'monospace',
                    ),
                decoration: InputDecoration(
                  hintText: '分 时 日 月 周',
                  helperText: '例如工作日早上九点：0 9 * * 1-5',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
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

class _StepField extends StatefulWidget {
  const _StepField({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.onInvalid,
    required this.fieldKey,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final ValueChanged<String> onInvalid;
  final Key fieldKey;

  @override
  State<_StepField> createState() => _StepFieldState();
}

class _StepFieldState extends State<_StepField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _padded(widget.value));
    _focus = FocusNode();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _StepField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _controller.text = _padded(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _padded(int value) => value.toString().padLeft(2, '0');

  void _onFocus() {
    if (_focus.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      return;
    }
    commit();
  }

  bool commit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 0 || parsed > widget.max) {
      _controller.text = _padded(widget.value);
      widget.onInvalid(
        widget.label == '时' ? '小时是 0 到 23' : '分钟是 0 到 59',
      );
      return false;
    }
    _controller.text = _padded(parsed);
    widget.onChanged(parsed);
    return true;
  }

  void _step(int delta) {
    final next = (widget.value + delta) % (widget.max + 1);
    final wrapped = next < 0 ? widget.max : next;
    widget.onChanged(wrapped);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.label,
      value: _padded(widget.value),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '减少${widget.label}',
              onPressed: () => _step(-1),
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    key: widget.fieldKey,
                    controller: _controller,
                    focusNode: _focus,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.headlineSmall,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => commit(),
                  ),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '增加${widget.label}',
              onPressed: () => _step(1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
