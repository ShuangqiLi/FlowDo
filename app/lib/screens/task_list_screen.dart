import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
import '../utils/speech_text.dart';
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
  final _speech = SpeechToText();
  bool _isListening = false;
  bool _voiceHeld = false;
  String _speechPrefix = '';

  /// 识别结果是异步回来的，松手或提交之后插件还会补发最后一次。换一轮编号，
  /// 让过期的那次回调直接丢掉，否则会把已经提交的标题重新写回输入框。
  int _speechSession = 0;

  /// 已经滑走、但服务端还没确认的任务。Slidable 要求滑动结束时立刻把卡片
  /// 移出列表，所以先本地隐藏，等刷新结果回来再决定是消失还是复原。
  final _dismissing = <String>{};

  /// 被退回的任务要换一个新的 Slidable，否则复用到的还是那个「已滑走」的状态。
  final _swipeGeneration = <String, int>{};

  @override
  void dispose() {
    _speech.cancel();
    _quickAdd.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(tasksProvider(widget.status));
    ref.invalidate(briefingProvider);
    try {
      await ref.read(tasksProvider(widget.status).future);
    } catch (_) {
      // 列表本身会渲染错误态，这里只要等这一轮刷新结束
    }
  }

  /// 滑动结束后立刻隐藏卡片，再把状态变更发给服务端。
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

  Future<void> _add() async {
    final title = _quickAdd.text.trim();
    if (title.isEmpty) {
      return;
    }
    await _endVoiceInput();
    _speechSession++;
    _speechPrefix = '';
    await ref.read(apiProvider).createTask(
          title: title,
          priority: 'MEDIUM',
        );
    _quickAdd.clear();
    await _refresh();
  }

  Future<void> _startVoiceInput() async {
    if (_voiceHeld) {
      return;
    }
    _voiceHeld = true;

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _isListening = status == 'listening');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音输入没听清：${error.errorMsg}')),
        );
      },
    );
    if (!available) {
      _voiceHeld = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备暂不支持语音输入')),
      );
      return;
    }
    if (!_voiceHeld) {
      // 初始化还没回来就松手了
      return;
    }

    final session = ++_speechSession;
    _speechPrefix = _quickAdd.text.trim();
    final locales = await _speech.locales();
    String? chineseLocale;
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('zh')) {
        chineseLocale = locale.localeId;
        break;
      }
    }
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: chineseLocale,
        pauseFor: const Duration(seconds: 30),
      ),
      onResult: (result) {
        if (session != _speechSession) {
          return;
        }
        final spoken = stripTrailingPunctuation(result.recognizedWords.trim());
        final text =
            [_speechPrefix, spoken].where((part) => part.isNotEmpty).join(' ');
        _quickAdd.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
    );
    if (!_voiceHeld) {
      await _speech.stop();
    }
  }

  Future<void> _endVoiceInput() async {
    _voiceHeld = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
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
      if (status == 'TODO' &&
          (widget.status == 'FOCUS' || widget.status == 'DONE')) {
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
    await ref.read(apiProvider).deleteTask(task.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tasksProvider(widget.status));
    final me = ref.watch(meProvider);
    final archiveDays = me.value?.archiveAfterDays ?? 7;
    final deleteDays = me.value?.deleteArchivedAfterDays ?? 30;
    final pointerActions = AppLayout.usesPointerActions(context);

    return ResponsiveContent(
      child: Column(
        children: [
          if (widget.status == 'TODO')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: QuickAddField(
                controller: _quickAdd,
                onSubmit: _add,
                onVoiceStart: _startVoiceInput,
                onVoiceEnd: _endVoiceInput,
                isListening: _isListening,
              ),
            ),
          Expanded(
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
                  child: SlidableAutoCloseBehavior(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final task = tasks[i];
                        final card = TaskCard(
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
                          onPickPriority: widget.status == 'ARCHIVED'
                              ? null
                              : (anchor) => _pickPriority(anchor, task),
                          actions: pointerActions ? _actions(task) : const [],
                        );
                        return pointerActions ? card : _wrapSwipe(task, card);
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
    final key = ValueKey('swipe-${task.id}-${_swipeGeneration[task.id] ?? 0}');
    switch (widget.status) {
      case 'TODO':
        return Slidable(
          key: key,
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              onDismissed: () => _dismissTo(task, 'FOCUS'),
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
          key: key,
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              onDismissed: () => _dismissTo(task, 'DONE'),
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
              onDismissed: () => _dismissTo(task, 'TODO'),
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
          key: key,
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.32,
            dismissible: DismissiblePane(
              onDismissed: () => _dismissTo(task, 'TODO'),
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
      case 'ARCHIVED':
        return Slidable(
          key: key,
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
      default:
        return child;
    }
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

  List<Widget> _actions(Task task) {
    switch (widget.status) {
      case 'TODO':
        return [
          IconButton(
            tooltip: '聚焦',
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: () => _setStatus(task, 'FOCUS'),
          ),
          IconButton(
            tooltip: '不做了',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(task),
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
