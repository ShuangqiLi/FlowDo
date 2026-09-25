import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/celebration_overlay.dart';
import '../ui/empty_state.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_dialog.dart';
import '../ui/flowdo_page_route.dart';
import '../ui/task_card.dart';
import '../ui/task_interactable.dart';
import '../widgets/priority_selector.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, required this.status});

  final String status;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  /// 已经滑走或拖走、但服务端还没确认的任务。先本地隐藏，刷新后再决定是否复原。
  final _dismissing = <String>{};

  /// 被退回的任务要换一个新的手势层，避免还停在滑出屏幕的位置。
  final _swipeGeneration = <String, int>{};

  Future<void> _refresh() async {
    ref.invalidate(tasksProvider(widget.status));
    ref.invalidate(briefingProvider);
    try {
      await ref.read(tasksProvider(widget.status).future);
    } catch (_) {
      // 列表本身会渲染错误态，这里只要等这一轮刷新结束
    }
  }

  void _dismissTo(Task task, String status) {
    setState(() => _dismissing.add(task.id));
    _setStatus(task, status).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _dismissing.remove(task.id);
        _swipeGeneration[task.id] = (_swipeGeneration[task.id] ?? 0) + 1;
      });
    });
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

  Future<void> _pickPriority(BuildContext anchorContext, Task task) async {
    final id = task.id;
    final current = task.priority;
    final chosen = await showPriorityPicker(
      anchorContext,
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
      message: archived
          ? '「${task.title}」删掉就回不来啦。'
          : '「${task.title}」会从任务池里拿走，回不来哦。',
      confirmLabel: '删掉',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    setState(() => _dismissing.add(task.id));
    try {
      await ref.read(apiProvider).deleteTask(task.id);
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _dismissing.remove(task.id));
      }
    }
  }

  Widget _card(Task task, int archiveDays, int deleteDays) {
    return TaskCard(
      task: task,
      subtitle: _subtitle(task, archiveDays, deleteDays),
      onOpen: () async {
        await Navigator.of(context).push(
          FlowDoPageRoute(
            swipeFromLeftEdgeOnly: false,
            builder: (_) => TaskDetailScreen(task: task),
          ),
        );
        await _refresh();
      },
      onPickPriority: widget.status == 'ARCHIVED'
          ? null
          : (anchor) => _pickPriority(anchor, task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tasksProvider(widget.status));
    final me = ref.watch(meProvider);
    final archiveDays = me.value?.archiveAfterDays ?? 7;
    final deleteDays = me.value?.deleteArchivedAfterDays ?? 30;

    return ResponsiveContent(
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final tasks = _dismissing.isEmpty
              ? all
              : all.where((t) => !_dismissing.contains(t.id)).toList();
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: tasks.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final task = tasks[i];
                final reduce = MediaQuery.disableAnimationsOf(context);
                final card = TaskInteractable(
                  key: ValueKey(
                    '${task.id}-${_swipeGeneration[task.id] ?? 0}',
                  ),
                  task: task,
                  onSwipeTo: (status) => _dismissTo(task, status),
                  onDelete: () => _delete(task),
                  child: _card(task, archiveDays, deleteDays),
                );
                if (reduce) {
                  return card;
                }
                return TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'fade-${task.id}-${_swipeGeneration[task.id] ?? 0}',
                  ),
                  tween: Tween(begin: 0, end: 1),
                  duration: AppMotion.standard,
                  curve: AppMotion.curve,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: child,
                  ),
                  child: card,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget? _subtitle(Task task, int archiveDays, int deleteDays) {
    switch (widget.status) {
      case 'TODO':
        return Text(task.listDateLabel());
      case 'DONE':
        final days = task.daysUntilArchive(archiveDays);
        final when = task.listDateLabel();
        return Text(days <= 0 ? '$when · 马上要归档啦' : '$when · 还有 $days 天归档');
      case 'ARCHIVED':
        return Text(task.archiveKeepHint(deleteDays));
      default:
        return null;
    }
  }

  String _emptyText(String status) {
    return switch (status) {
      'TODO' => '任务池空空的。\n点加号，想到什么就丢进来。',
      'FOCUS' => '还没在盯什么。\n从任务池挑一件开始。',
      'DONE' => '还没有搞定的事，慢慢来。',
      'ARCHIVED' => '归档柜空着，挺清爽。',
      _ => '暂时没有任务',
    };
  }
}
