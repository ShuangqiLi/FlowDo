import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/celebration_overlay.dart';
import '../ui/empty_state.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_dialog.dart';
import '../ui/flowdo_page_route.dart';
import '../ui/focus_admission.dart';
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
  final _focusAdmission = FocusAdmission();

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
  }

  int _hold(String id, Task? task) {
    return ref.read(pendingTaskWritesProvider).begin(
          id: id,
          spaceId: ref.read(meProvider).value?.activeSpaceId,
          task: task,
        );
  }

  void _finishWrite(String id, int gen) {
    ref.read(lazySyncProvider.notifier).settleWrite(id, gen);
    ref.read(lazySyncProvider.notifier).schedule();
  }

  Future<T> _queued<T>(String id, Future<T> Function() job) {
    return ref.read(taskWriteQueueProvider).run(id, job);
  }

  Future<List<String>> _focusedIds() async {
    final current = ref.read(tasksProvider('FOCUS'));
    if (current.hasValue) {
      return current.value!.map((task) => task.id).toList();
    }
    // 首页四个列表常驻时走内存；单测或尚未加载时再拉一次聚焦表。
    try {
      final tasks = await ref.read(tasksProvider('FOCUS').future);
      return tasks.map((task) => task.id).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _setStatus(Task task, String status) async {
    var heldFocus = false;
    if (status == 'FOCUS') {
      final limit = ref.read(meProvider).value?.focusLimit ?? 3;
      heldFocus = await _focusAdmission.tryAdmit(
        taskId: task.id,
        limit: limit,
        focusedIds: _focusedIds,
      );
      if (!heldFocus) {
        _goFocusWithHint(
          '手头这 $limit 件先盯紧啦。完成或先放回任务池，再接新的。',
        );
        return;
      }
    }

    if (status == 'DONE' && task.priority == 'REMINDER') {
      final gen = _hold(task.id, null);
      ref.read(tasksProvider(widget.status).notifier).removeById(task.id);
      if (mounted) {
        showFlowDoCelebration(context);
      }
      try {
        await _queued(
          task.id,
          () => ref.read(apiProvider).updateTask(task.id, status: status),
        );
        for (final listStatus in taskListStatuses) {
          if (ref.exists(tasksProvider(listStatus))) {
            ref.read(tasksProvider(listStatus).notifier).removeById(task.id);
          }
        }
        _finishWrite(task.id, gen);
      } on ApiException catch (e) {
        _finishWrite(task.id, gen);
        if (ref.exists(tasksProvider(widget.status))) {
          ref.read(tasksProvider(widget.status).notifier).upsert(task);
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _dismissing.remove(task.id);
          _swipeGeneration[task.id] = (_swipeGeneration[task.id] ?? 0) + 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    }

    final now = DateTime.now();
    final optimistic = task.copyWith(
      status: status,
      completedAt: status == 'DONE' ? (task.completedAt ?? now) : task.completedAt,
      clearCompletedAt: status != 'DONE' && task.status == 'DONE',
      archivedAt: status == 'ARCHIVED' ? (task.archivedAt ?? now) : task.archivedAt,
      clearArchivedAt: status != 'ARCHIVED' && task.status == 'ARCHIVED',
      updatedAt: now,
    );
    final gen = _hold(task.id, optimistic);
    _applyStatusLocally(optimistic, widget.status);
    if (status == 'DONE' && mounted) {
      showFlowDoCelebration(context);
    }

    try {
      final updated = await _queued(
        task.id,
        () => ref.read(apiProvider).updateTask(task.id, status: status),
      );
      final dest = tasksProvider(updated.status);
      if (ref.exists(dest) && ref.read(dest).hasValue) {
        ref.read(dest.notifier).upsert(updated);
      }
      _finishWrite(task.id, gen);
    } on ApiException catch (e) {
      _finishWrite(task.id, gen);
      ref.read(tasksProvider(status).notifier).removeById(task.id);
      if (ref.exists(tasksProvider(widget.status))) {
        ref.read(tasksProvider(widget.status).notifier).upsert(task);
      }
      if (mounted) {
        setState(() {
          _dismissing.remove(task.id);
          _swipeGeneration[task.id] = (_swipeGeneration[task.id] ?? 0) + 1;
        });
      }
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
    } catch (e) {
      _finishWrite(task.id, gen);
      ref.read(tasksProvider(status).notifier).removeById(task.id);
      if (ref.exists(tasksProvider(widget.status))) {
        ref.read(tasksProvider(widget.status).notifier).upsert(task);
      }
      if (mounted) {
        setState(() {
          _dismissing.remove(task.id);
          _swipeGeneration[task.id] = (_swipeGeneration[task.id] ?? 0) + 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (heldFocus) {
        _focusAdmission.release(task.id);
      }
    }
  }

  Future<void> _pickPriority(BuildContext anchorContext, Task task) async {
    final id = task.id;
    final current = task.priority;
    final chosen = await showPriorityPicker(
      anchorContext,
      current: current,
    );
    if (chosen == null || !anchorContext.mounted) {
      return;
    }
    if (chosen == current && chosen != 'REMINDER') {
      return;
    }
    ReminderPlan? plan;
    if (chosen == 'REMINDER') {
      plan = await showReminderTimePicker(
        anchorContext,
        initial: task.remindAt,
        repeat: task.remindRepeat,
      );
      if (plan == null || !anchorContext.mounted) {
        return;
      }
    }
    final optimistic = task.copyWith(
      priority: chosen,
      remindAt: plan?.at,
      remindRepeat: plan?.repeat,
      clearRemindAt: chosen != 'REMINDER',
      updatedAt: DateTime.now(),
    );
    final gen = _hold(id, optimistic);
    ref.read(tasksProvider(widget.status).notifier).upsert(optimistic);
    try {
      final updated = await _queued(
        id,
        () => ref.read(apiProvider).updateTask(
              id,
              priority: chosen,
              remindAt: plan?.at,
              remindRepeat: plan?.repeat,
              clearRemindAt: chosen != 'REMINDER',
            ),
      );
      ref.read(tasksProvider(widget.status).notifier).upsert(updated);
      _finishWrite(id, gen);
    } on ApiException catch (e) {
      _finishWrite(id, gen);
      ref.read(tasksProvider(widget.status).notifier).upsert(task);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
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
    final gen = _hold(task.id, null);
    ref.read(tasksProvider(widget.status).notifier).removeById(task.id);
    unawaited(() async {
      try {
        await ref.read(apiProvider).deleteTask(task.id);
        _finishWrite(task.id, gen);
      } on ApiException catch (e) {
        _finishWrite(task.id, gen);
        ref.read(tasksProvider(widget.status).notifier).upsert(task);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } catch (e) {
        _finishWrite(task.id, gen);
        ref.read(tasksProvider(widget.status).notifier).upsert(task);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _dismissing.remove(task.id));
        }
      }
    }());
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
        ref.read(lazySyncProvider.notifier).protectLocalWrite();
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
            physics: refreshScrollPhysics,
            children: [
              SizedBox(
                height: 280,
                child: Center(child: Text('$e')),
              ),
            ],
          ),
        ),
        data: (all) {
          final showSeries = me.value?.showRecurringReminders ?? true;
          final visible = all.where((task) {
            if (widget.status != 'TODO' || showSeries) {
              return true;
            }
            return task.priority != 'REMINDER' || task.remindRepeat == 'ONCE';
          });
          final tasks = _dismissing.isEmpty
              ? visible.toList()
              : visible.where((t) => !_dismissing.contains(t.id)).toList();
          _scrollToPending(tasks);
          if (tasks.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: refreshScrollPhysics,
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
              physics: refreshScrollPhysics,
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
        if (task.priority == 'REMINDER' && task.remindAt != null) {
          final when = DateFormat('M月d日 HH:mm').format(task.remindAt!.toLocal());
          final repeat = remindRepeatLabel(task.remindRepeat);
          return Text(repeat == '仅一次' ? '提醒 $when' : '$repeat · $when');
        }
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
      'DONE' => '还没有完成的事，慢慢来。',
      'ARCHIVED' => '归档柜空着，挺清爽。',
      _ => '暂时没有任务',
    };
  }
}
