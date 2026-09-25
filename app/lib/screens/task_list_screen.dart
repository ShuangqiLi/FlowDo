import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/celebration_overlay.dart';
import '../ui/empty_state.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_dialog.dart';
import '../ui/quick_add_field.dart';
import '../ui/task_card.dart';
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
    ref.read(homeTabProvider.notifier).setIndex(1);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setStatus(Task task, String status) async {
    if (status == 'FOCUS') {
      final limit = ref.read(meProvider).value?.focusLimit ?? 3;
      final focused = ref.read(tasksProvider('FOCUS')).value?.length ?? 0;
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
      if (status == 'DONE' && mounted) {
        showFlowDoCelebration(context);
      }
      await _refresh();
      if (status != widget.status) {
        ref.invalidate(tasksProvider(status));
      }
      if (status == 'TODO' && (widget.status == 'FOCUS' || widget.status == 'DONE')) {
        ref.read(homeTabProvider.notifier).setIndex(0);
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
    final ok = await showFlowDoConfirmDialog(
      context,
      title: archived ? '清掉这条归档？' : '不做了？',
      message: archived ? '「${task.title}」删掉就回不来啦。' : '「${task.title}」会从任务池里拿走，回不来哦。',
      confirmLabel: '删掉',
      destructive: true,
    );
    if (!ok) {
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
    final archiveDays = me.value?.archiveAfterDays ?? 7;
    final deleteDays = me.value?.deleteArchivedAfterDays ?? 30;
    final scheme = Theme.of(context).colorScheme;

    return ResponsiveContent(
      child: Column(
        children: [
          if (widget.status == 'TODO')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuickAddField(
                    controller: _quickAdd,
                    onSubmit: _add,
                  ),
                  const SizedBox(height: 10),
                  FlowDoCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Focus(
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
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PrioritySelector(
                                  value: _newPriority,
                                  onChanged: (v) => setState(() => _newPriority = v),
                                ),
                              ),
                            ],
                          ),
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
                          child: EmptyState(
                            icon: Icons.inbox_rounded,
                            message: _emptyText(widget.status),
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
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final task = tasks[i];
                        return _wrapSwipe(
                          task,
                          TaskCard(
                            key: ValueKey(task.id),
                            task: task,
                            subtitle: _subtitle(task, archiveDays, deleteDays),
                            onOpen: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TaskDetailScreen(task: task),
                                ),
                              );
                              await _refresh();
                            },
                            onPickPriority:
                                widget.status == 'ARCHIVED' ? null : () => _pickPriority(task),
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
      ),
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
                icon: Icons.center_focus_strong_rounded,
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
                icon: Icons.delete_outline_rounded,
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
                icon: Icons.check_circle_rounded,
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
                icon: Icons.inbox_rounded,
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
                icon: Icons.undo_rounded,
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
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: () => _setStatus(task, 'FOCUS'),
          ),
        ];
      case 'FOCUS':
        return [
          IconButton(
            tooltip: '先放回任务池',
            icon: const Icon(Icons.inbox_rounded),
            onPressed: () => _setStatus(task, 'TODO'),
          ),
          IconButton(
            tooltip: '搞定啦',
            icon: const Icon(Icons.check_circle_rounded),
            onPressed: () => _setStatus(task, 'DONE'),
          ),
        ];
      case 'DONE':
        return [
          IconButton(
            tooltip: '先放回任务池',
            icon: const Icon(Icons.undo_rounded),
            onPressed: () => _setStatus(task, 'TODO'),
          ),
        ];
      case 'ARCHIVED':
        return [
          IconButton(
            tooltip: '清掉',
            icon: const Icon(Icons.delete_outline_rounded),
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
