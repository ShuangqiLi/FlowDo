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
import '../ui/focus_dock.dart';
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

class _TaskListScreenState extends ConsumerState<TaskListScreen>
    with AutomaticKeepAliveClientMixin {
  /// 已经滑走或拖走、但服务端还没确认的任务。先本地隐藏，刷新后再决定是否复原。
  final _dismissing = <String>{};

  /// 被退回的任务要换一个新的手势层，避免还停在滑出屏幕的位置。
  final _swipeGeneration = <String, int>{};
  final _scroll = ScrollController();
  final _itemKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToPending(List<Task> tasks, {int attempt = 0}) {
    final id = ref.read(pendingScrollTaskIdProvider);
    if (widget.status != 'TODO' || id == null) {
      return;
    }
    if (!tasks.any((task) => task.id == id)) {
      if (attempt >= 12) {
        ref.read(pendingScrollTaskIdProvider.notifier).clear();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToPending(tasks, attempt: attempt + 1);
          }
        });
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = _itemKeys[id]?.currentContext;
      if (target == null) {
        if (attempt >= 12) {
          ref.read(pendingScrollTaskIdProvider.notifier).clear();
        } else {
          _scrollToPending(tasks, attempt: attempt + 1);
        }
        return;
      }
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: AppMotion.quick,
        curve: AppMotion.curve,
      );
      ref.read(pendingScrollTaskIdProvider.notifier).clear();
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() => ref.read(lazySyncProvider.notifier).pull();

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
    ref.read(homeTabProvider.notifier).setTab(HomeTab.focus);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _applyStatusLocally(Task updated, String fromStatus) {
    ref.read(tasksProvider(fromStatus).notifier).removeById(updated.id);
    final dest = tasksProvider(updated.status);
    if (ref.exists(dest) && ref.read(dest).hasValue) {
      ref.read(dest.notifier).upsert(updated);
    }
    ref.read(lazySyncProvider.notifier).schedule();
  }

  Future<void> _setStatus(Task task, String status) async {
    if (status == 'FOCUS') {
      final limit = ref.read(meProvider).value?.focusLimit ?? 3;
      final focused = ref.read(tasksProvider('FOCUS')).value?.length ?? 0;
      if (focused >= limit) {
        _goFocusWithHint(
          '手头这 $limit 件先盯紧啦。搞定或先放回任务池，再接新的。',
        );
        return;
      }
    }
    try {
      final updated =
          await ref.read(apiProvider).updateTask(task.id, status: status);
      if (status == 'DONE' && mounted) {
        showFlowDoCelebration(context);
      }
      _applyStatusLocally(updated, widget.status);
    } on ApiException catch (e) {
      if (status == 'FOCUS') {
        _goFocusWithHint(e.message);
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
    final updated =
        await ref.read(apiProvider).updateTask(id, priority: chosen);
    ref.read(tasksProvider(widget.status).notifier).upsert(updated);
    ref.read(lazySyncProvider.notifier).schedule();
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
      ref.read(tasksProvider(widget.status).notifier).removeById(task.id);
      ref.read(lazySyncProvider.notifier).schedule();
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
        ref.read(lazySyncProvider.notifier).schedule();
      },
      onPickPriority: widget.status == 'ARCHIVED'
          ? null
          : (anchor) => _pickPriority(anchor, task),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(tasksProvider(widget.status));
    final me = ref.watch(meProvider);
    final archiveDays = me.value?.archiveAfterDays ?? 7;
    final deleteDays = me.value?.deleteArchivedAfterDays ?? 30;

    return ResponsiveContent(
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            children: [
              SizedBox(
                height: 280,
                child: Center(child: Text('$e')),
              ),
            ],
          ),
        ),
        data: (all) {
          final tasks = _dismissing.isEmpty
              ? all
              : all.where((t) => !_dismissing.contains(t.id)).toList();
          _scrollToPending(tasks);
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
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: tasks.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final task = tasks[i];
                return KeyedSubtree(
                  key: _itemKeys.putIfAbsent(task.id, GlobalKey.new),
                  child: TaskInteractable(
                  key: ValueKey(
                    '${task.id}-${_swipeGeneration[task.id] ?? 0}',
                  ),
                  task: task,
                  onSwipeTo: (status) => _dismissTo(task, status),
                  onDelete: () => _delete(task),
                  child: _card(task, archiveDays, deleteDays),
                ),
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
