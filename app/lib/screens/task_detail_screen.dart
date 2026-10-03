import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';
import '../widgets/priority_selector.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late Task _task;
  bool _saving = false;
  bool _moving = false;
  bool _rescheduling = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _title = TextEditingController(text: widget.task.title);
    _body = TextEditingController(text: widget.task.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _dirty {
    final title = _title.text.trim();
    final body = _body.text;
    final originalBody = widget.task.body ?? '';
    return title != widget.task.title || body != originalBody;
  }

  bool get _archived => widget.task.status == 'ARCHIVED';

  Future<void> _saveIfNeeded() async {
    if (_saving || !_dirty || _archived) {
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }
    _saving = true;
    try {
      final updated = await ref.read(taskWriteQueueProvider).run(
            widget.task.id,
            () => ref.read(apiProvider).updateTask(
                  widget.task.id,
                  title: title,
                  body: _body.text,
                ),
          );
      if (mounted) {
        setState(() => _task = updated);
      }
      if (ref.exists(tasksProvider(updated.status))) {
        ref.read(tasksProvider(updated.status).notifier).upsert(updated);
      }
      ref.read(lazySyncProvider.notifier).protectLocalWrite();
      ref.read(lazySyncProvider.notifier).schedule();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _onClose() async {
    await _saveIfNeeded();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _moveToSpace(String spaceId) async {
    if (_moving || _archived) {
      return;
    }
    setState(() => _moving = true);
    final gen = ref.read(pendingTaskWritesProvider).begin(
          id: widget.task.id,
          spaceId: ref.read(meProvider).value?.activeSpaceId,
          task: null,
        );
    if (ref.exists(tasksProvider(widget.task.status))) {
      ref
          .read(tasksProvider(widget.task.status).notifier)
          .removeById(widget.task.id);
    }
    try {
      await _saveIfNeeded();
      await ref.read(taskWriteQueueProvider).run(
            widget.task.id,
            () => ref
                .read(apiProvider)
                .updateTask(widget.task.id, spaceId: spaceId),
          );
      ref.read(lazySyncProvider.notifier).settleWrite(widget.task.id, gen);
      ref.read(lazySyncProvider.notifier).schedule();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      ref.read(lazySyncProvider.notifier).settleWrite(widget.task.id, gen);
      if (ref.exists(tasksProvider(widget.task.status))) {
        ref
            .read(tasksProvider(widget.task.status).notifier)
            .upsert(widget.task);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      ref.read(lazySyncProvider.notifier).settleWrite(widget.task.id, gen);
      if (ref.exists(tasksProvider(widget.task.status))) {
        ref
            .read(tasksProvider(widget.task.status).notifier)
            .upsert(widget.task);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _moving = false);
      }
    }
  }

  Future<void> _reschedule() async {
    if (_rescheduling || _archived) {
      return;
    }
    final plan = await showReminderTimePicker(
      context,
      initial: _task.remindAt,
      repeat: _task.remindRepeat,
      cron: _task.remindCron,
      lunar: _task.remindLunar,
    );
    if (plan == null || !mounted) {
      return;
    }
    setState(() => _rescheduling = true);
    try {
      final updated = await ref.read(taskWriteQueueProvider).run(
            _task.id,
            () => ref.read(apiProvider).updateTask(
                  _task.id,
                  priority: 'REMINDER',
                  remindAt: plan.at,
                  remindRepeat: plan.repeat,
                  remindCron: plan.cron,
                  remindLunar: plan.lunar,
                  clearRemindCron: plan.repeat != 'CRON',
                ),
          );
      if (ref.exists(tasksProvider(updated.status))) {
        ref.read(tasksProvider(updated.status).notifier).upsert(updated);
      }
      ref.read(lazySyncProvider.notifier).protectLocalWrite();
      ref.read(lazySyncProvider.notifier).schedule();
      if (mounted) {
        setState(() => _task = updated);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _rescheduling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spaces = ref.watch(spacesProvider).value ?? const [];
    final activeId = ref.watch(meProvider).value?.activeSpaceId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _onClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('任务详情'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onClose,
          ),
          actions: [
            if (!_archived && spaces.length > 1)
              PopupMenuButton<String>(
                tooltip: '换到别的空间',
                enabled: !_moving,
                onSelected: _moveToSpace,
                itemBuilder: (context) => [
                  for (final space in spaces)
                    PopupMenuItem(
                      value: space.id,
                      enabled: space.id != activeId,
                      child: Row(
                        children: [
                          Icon(
                            space.id == activeId
                                ? Icons.check_rounded
                                : Icons.layers_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              space.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                icon: const Icon(Icons.drive_file_move_outline),
              ),
          ],
        ),
        body: ResponsiveContent(
          maxWidth: AppLayout.readingMaxWidth,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TaskFactsRow(task: _task),
                const SizedBox(height: AppSpacing.sm),
                FlowDoCard(
                  child: TextField(
                    controller: _title,
                    readOnly: _archived,
                    decoration: const InputDecoration(
                      labelText: '要办的事',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_task.priority == 'REMINDER') ...[
                  _ReminderCard(
                    task: _task,
                    busy: _rescheduling,
                    onReschedule: _archived ? null : _reschedule,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_archived) ...[
                  Text(
                    '这条已经收进归档，只能看看。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_task.priority != 'REMINDER')
                  Expanded(
                    child: FlowDoCard(
                      child: TextField(
                        controller: _body,
                        readOnly: _archived,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          labelText: '过程小记',
                          hintText: _archived ? null : '想到什么就记一笔（可选）',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 状态、优先级和日期的一行小标签。
class _TaskFactsRow extends StatelessWidget {
  const _TaskFactsRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = switch (task.status) {
      'FOCUS' => '聚焦中',
      'DONE' => '已完成',
      'ARCHIVED' => '已归档',
      _ => '在任务池',
    };
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        _Fact(icon: Icons.layers_outlined, text: status),
        _Fact(
          icon: task.priority == 'REMINDER'
              ? Icons.flag_rounded
              : Icons.label_important_outline_rounded,
          text: task.priority == 'REMINDER' ? '提醒' : '${task.priorityLabel}优先级',
          color: priorityColor(context, task.priority),
        ),
        _Fact(
          icon: Icons.schedule_rounded,
          text: task.listDateLabel(),
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ink),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// 提醒任务：什么时候响、多久一次、还有多久。
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.task,
    required this.busy,
    required this.onReschedule,
  });

  final Task task;
  final bool busy;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final at = task.remindAt?.toLocal();
    final repeat = task.remindRepeat == 'CRON' && (task.remindCron ?? '').isNotEmpty
        ? 'crontab ${task.remindCron}'
        : remindRepeatLabel(task.remindRepeat);
    final recurring = task.remindRepeat != 'ONCE';
    final when = at == null
        ? '还没定时间'
        : reminderWhenText(at, lunar: task.remindLunar, withYear: true);
    final countdown = at == null ? null : _countdown(at, DateTime.now());
    final note = recurring
        ? '到点会复制一份放进聚焦，做完那一份就删掉；这条循环会继续排下一次。'
        : task.status == 'FOCUS'
            ? '已经到点进了聚焦，完成后会直接删掉。'
            : '到点会自动进聚焦，并在右上角通知里提醒你。完成后直接删掉。';

    return FlowDoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  when,
                  key: const ValueKey('reminder-when'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onReschedule != null)
                TextButton(
                  onPressed: busy ? null : onReschedule,
                  child: Text(busy ? '改中…' : '改时间'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            countdown == null ? repeat : '$repeat · $countdown',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  static String _countdown(DateTime at, DateTime now) {
    final diff = at.difference(now);
    if (diff.isNegative) {
      return '已到点';
    }
    if (diff.inMinutes < 1) {
      return '马上';
    }
    if (diff.inHours < 1) {
      return '还有 ${diff.inMinutes} 分钟';
    }
    if (diff.inDays < 1) {
      final minutes = diff.inMinutes % 60;
      return minutes == 0
          ? '还有 ${diff.inHours} 小时'
          : '还有 ${diff.inHours} 小时 $minutes 分';
    }
    final hours = diff.inHours % 24;
    return hours == 0 ? '还有 ${diff.inDays} 天' : '还有 ${diff.inDays} 天 $hours 小时';
  }
}
