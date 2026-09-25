import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import '../providers.dart';
import '../widgets/priority_selector.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, required this.status});

  final String status;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _quickAdd = TextEditingController();
  final _priorityFocus = FocusNode(debugLabel: 'newPriority');
  String _newPriority = 'MEDIUM';
  double? _priorityPointerStartX;

  @override
  void initState() {
    super.initState();
    if (widget.status == 'TODO') {
      HardwareKeyboard.instance.addHandler(_handlePriorityKey);
    }
  }

  @override
  void dispose() {
    if (widget.status == 'TODO') {
      HardwareKeyboard.instance.removeHandler(_handlePriorityKey);
    }
    _priorityFocus.dispose();
    _quickAdd.dispose();
    super.dispose();
  }

  bool _handlePriorityKey(KeyEvent event) {
    if (widget.status != 'TODO') {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (ref.read(homeTabProvider) != 0) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _cycleNewPriority(-1);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _cycleNewPriority(1);
      return true;
    }
    return false;
  }

  Future<void> _refresh() async {
    ref.invalidate(tasksProvider(widget.status));
    ref.invalidate(briefingProvider);
  }

  Future<void> _add() async {
    final title = _quickAdd.text.trim();
    if (title.isEmpty) {
      return;
    }
    await ref.read(apiProvider).createTask(
          title: title,
          priority: _newPriority,
        );
    _quickAdd.clear();
    await _refresh();
  }

  void _goFocusWithHint(String message) {
    ref.read(homeTabProvider.notifier).state = 1;
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setStatus(Task task, String status) async {
    if (status == 'FOCUS') {
      final limit = ref.read(meProvider).valueOrNull?.focusLimit ?? 3;
      final focused =
          ref.read(tasksProvider('FOCUS')).valueOrNull?.length ?? 0;
      if (focused >= limit) {
        _goFocusWithHint(
          '手头这 $limit 件先盯紧啦。搞定或先放回任务池，再接新的。',
        );
        await _refresh();
        return;
      }
    }
    try {
      await ref.read(apiProvider).updateTask(task.id, status: status);
      await _refresh();
      if (status != widget.status) {
        ref.invalidate(tasksProvider(status));
      }
      if (status == 'TODO' &&
          (widget.status == 'FOCUS' || widget.status == 'DONE')) {
        ref.read(homeTabProvider.notifier).state = 0;
      }
    } on ApiException catch (e) {
      if (status == 'FOCUS') {
        _goFocusWithHint(e.message);
        await _refresh();
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _pickPriority(Task task) async {
    final id = task.id;
    final current = task.priority;
    final chosen = await showPriorityPicker(
      context,
      current: current,
    );
    if (chosen == null || chosen == current) {
      return;
    }
    await ref.read(apiProvider).updateTask(id, priority: chosen);
    await _refresh();
  }

  Future<void> _delete(Task task) async {
    final archived = task.status == 'ARCHIVED';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(archived ? '清掉这条归档？' : '不做了？'),
        content: Text(
          archived
              ? '「${task.title}」删掉就回不来啦。'
              : '「${task.title}」会从任务池里拿走，回不来哦。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('先留着'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删掉'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await ref.read(apiProvider).deleteTask(task.id);
    await _refresh();
  }

  void _cycleNewPriority(int delta) {
    final i = priorityOrder.indexOf(_newPriority);
    final next = (i + delta) % priorityOrder.length;
    final index = next < 0 ? next + priorityOrder.length : next;
    setState(() => _newPriority = priorityOrder[index]);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tasksProvider(widget.status));
    final me = ref.watch(meProvider);
    final archiveDays = me.valueOrNull?.archiveAfterDays ?? 7;
    final deleteDays = me.valueOrNull?.deleteArchivedAfterDays ?? 30;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (widget.status == 'TODO')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _quickAdd,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: '想到什么？点右边加入任务池',
                    prefixIcon: const Icon(Icons.add_task_outlined),
                    suffixIcon: IconButton(
                      tooltip: '添加',
                      onPressed: _add,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ),
                  onSubmitted: (_) => _add(),
                ),
                const SizedBox(height: 10),
                Focus(
                  focusNode: _priorityFocus,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      _priorityPointerStartX = event.position.dx;
                      _priorityFocus.requestFocus();
                    },
                    onPointerUp: (event) {
                      final start = _priorityPointerStartX;
                      _priorityPointerStartX = null;
                      if (start == null) {
                        return;
                      }
                      final dx = event.position.dx - start;
                      if (dx > 48) {
                        _cycleNewPriority(-1);
                      } else if (dx < -48) {
                        _cycleNewPriority(1);
                      }
                    },
                    onPointerCancel: (_) => _priorityPointerStartX = null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            '优先级',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrioritySelector(
                              value: _newPriority,
                              onChanged: (v) =>
                                  setState(() => _newPriority = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (tasks) {
              if (tasks.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 280,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: scheme.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _emptyText(widget.status),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: SlidableAutoCloseBehavior(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      return _wrapSwipe(
                        task,
                        _TaskRow(
                          key: ValueKey(task.id),
                          task: task,
                          subtitle: _subtitle(task, archiveDays, deleteDays),
                          accent: priorityColor(task.priority),
                          onOpen: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(task: task),
                              ),
                            );
                            await _refresh();
                          },
                          onPickPriority: widget.status == 'ARCHIVED'
                              ? null
                              : () => _pickPriority(task),
                          actions: _actions(task),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _wrapSwipe(Task task, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    switch (widget.status) {
      case 'TODO':
        return Slidable(
          key: ValueKey('swipe-${task.id}'),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              onDismissed: () => _setStatus(task, 'FOCUS'),
            ),
            children: [
              SlidableAction(
                onPressed: (_) => _setStatus(task, 'FOCUS'),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                icon: Icons.center_focus_strong,
                label: '聚焦',
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            children: [
              SlidableAction(
                onPressed: (_) => _delete(task),
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                icon: Icons.delete_outline,
                label: '删除',
              ),
            ],
          ),
          child: child,
        );
      case 'FOCUS':
        return Slidable(
          key: ValueKey('swipe-${task.id}'),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              onDismissed: () => _setStatus(task, 'DONE'),
            ),
            children: [
              SlidableAction(
                onPressed: (_) => _setStatus(task, 'DONE'),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                icon: Icons.check_circle_outline,
                label: '完成',
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.32,
            dismissible: DismissiblePane(
              onDismissed: () => _setStatus(task, 'TODO'),
            ),
            children: [
              SlidableAction(
                onPressed: (_) => _setStatus(task, 'TODO'),
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                icon: Icons.inbox_outlined,
                label: '任务池',
              ),
            ],
          ),
          child: child,
        );
      case 'DONE':
        return Slidable(
          key: ValueKey('swipe-${task.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.32,
            dismissible: DismissiblePane(
              onDismissed: () => _setStatus(task, 'TODO'),
            ),
            children: [
              SlidableAction(
                onPressed: (_) => _setStatus(task, 'TODO'),
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                icon: Icons.undo,
                label: '任务池',
              ),
            ],
          ),
          child: child,
        );
      default:
        return child;
    }
  }

  Widget? _subtitle(Task task, int archiveDays, int deleteDays) {
    if (widget.status == 'DONE') {
      final days = task.daysUntilArchive(archiveDays);
      return Text(days <= 0 ? '马上要归档啦' : '还有 $days 天归档');
    }
    if (widget.status == 'ARCHIVED') {
      final days = task.daysUntilDelete(deleteDays);
      return Text(days <= 0 ? '马上要清掉啦' : '还有 $days 天自动清掉');
    }
    return null;
  }

  List<Widget> _actions(Task task) {
    switch (widget.status) {
      case 'TODO':
        return [
          IconButton(
            tooltip: '聚焦',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => _setStatus(task, 'FOCUS'),
          ),
        ];
      case 'FOCUS':
        return [
          IconButton(
            tooltip: '先放回任务池',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => _setStatus(task, 'TODO'),
          ),
          IconButton(
            tooltip: '搞定啦',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _setStatus(task, 'DONE'),
          ),
        ];
      case 'DONE':
        return [
          IconButton(
            tooltip: '先放回任务池',
            icon: const Icon(Icons.undo),
            onPressed: () => _setStatus(task, 'TODO'),
          ),
        ];
      case 'ARCHIVED':
        return [
          IconButton(
            tooltip: '清掉',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(task),
          ),
        ];
      default:
        return [];
    }
  }

  String _emptyText(String status) {
    return switch (status) {
      'TODO' => '任务池空空的。\n想到什么就先丢进来吧。',
      'FOCUS' => '还没在盯什么。\n从任务池挑一件开始。',
      'DONE' => '还没有搞定的事，慢慢来。',
      'ARCHIVED' => '归档柜空着，挺清爽。',
      _ => '暂时没有任务',
    };
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.accent,
    required this.onOpen,
    this.onPickPriority,
    required this.actions,
    this.subtitle,
  });

  final Task task;
  final Color accent;
  final Widget? subtitle;
  final VoidCallback onOpen;
  final VoidCallback? onPickPriority;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.7),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPickPriority,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    child: Center(
                      child: PriorityBadge(priority: task.priority),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 4, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            DefaultTextStyle(
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              child: subtitle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          ),
        ),
      ),
    );
  }
}
