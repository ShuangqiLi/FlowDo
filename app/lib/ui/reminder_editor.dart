import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';

const _lunarMonths = ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'];

/// 新建一条提醒。公历用系统日期，农历选月日，可标闰月。
Future<bool> showReminderEditor(
  BuildContext context,
  ApiClient api, {
  DateTime? initialDate,
}) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _ReminderEditorDialog(
      api: api,
      initialDate: initialDate ?? DateTime.now(),
    ),
  );
  return created ?? false;
}

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog({required this.api, required this.initialDate});

  final ApiClient api;
  final DateTime initialDate;

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  final _title = TextEditingController();
  bool _lunar = false;
  bool _leap = false;
  bool _anniversary = false;
  bool _busy = false;
  String _recurrence = 'NONE';
  late DateTime _solar = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
    widget.initialDate.day,
  );
  int _lunarMonth = 1;
  int _lunarDay = 1;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickSolar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _solar,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _solar = picked);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '写一下要提醒什么');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final recurrence = _anniversary
        ? 'YEARLY'
        : (_lunar && (_recurrence == 'DAILY' || _recurrence == 'WEEKLY'))
            ? 'YEARLY'
            : _recurrence;
    final body = <String, dynamic>{
      'title': title,
      'calendar': _lunar ? 'LUNAR' : 'SOLAR',
      'recurrence': recurrence,
      'kind': _anniversary ? 'ANNIVERSARY' : 'NORMAL',
      if (!_lunar)
        'date':
            '${_solar.year.toString().padLeft(4, '0')}-${_solar.month.toString().padLeft(2, '0')}-${_solar.day.toString().padLeft(2, '0')}',
      if (_lunar) ...{
        'lunarMonth': _lunarMonth,
        'lunarDay': _lunarDay,
        'leapMonth': _leap,
      },
    };
    try {
      await widget.api.createReminder(body);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recurrences = _lunar
        ? const [('NONE', '一次'), ('MONTHLY', '每月'), ('YEARLY', '每年')]
        : const [
            ('NONE', '一次'),
            ('DAILY', '每天'),
            ('WEEKLY', '每周'),
            ('MONTHLY', '每月'),
            ('YEARLY', '每年'),
          ];
    final shownRecurrence = _anniversary
        ? 'YEARLY'
        : (_lunar && (_recurrence == 'DAILY' || _recurrence == 'WEEKLY'))
            ? 'YEARLY'
            : _recurrence;

    return AlertDialog(
      title: const Text('新提醒'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: '要提醒什么'),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('公历')),
                ButtonSegment(value: true, label: Text('农历')),
              ],
              selected: {_lunar},
              onSelectionChanged: (value) => setState(() => _lunar = value.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!_lunar)
              OutlinedButton(
                onPressed: _pickSolar,
                child: Text('${_solar.year}年${_solar.month}月${_solar.day}日'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _lunarMonth,
                      items: [
                        for (var i = 1; i <= 12; i++)
                          DropdownMenuItem(value: i, child: Text('${_lunarMonths[i - 1]}月')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _lunarMonth = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _lunarDay,
                      items: [
                        for (var i = 1; i <= 30; i++)
                          DropdownMenuItem(value: i, child: Text('$i日')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _lunarDay = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            if (_lunar)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('闰月'),
                value: _leap,
                onChanged: (value) => setState(() => _leap = value),
              ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButton<String>(
              isExpanded: true,
              value: shownRecurrence,
              items: [
                for (final item in recurrences)
                  DropdownMenuItem(value: item.$1, child: Text(item.$2)),
              ],
              onChanged: _anniversary
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _recurrence = value);
                      }
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('纪念日'),
              subtitle: const Text('每年同一天'),
              value: _anniversary,
              onChanged: (value) => setState(() => _anniversary = value),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('记下'),
        ),
      ],
    );
  }
}
