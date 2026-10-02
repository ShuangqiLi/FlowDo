import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _saving = false;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
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
      final updated = await ref.read(apiProvider).updateTask(
            widget.task.id,
            title: title,
            body: _body.text,
          );
      if (ref.exists(tasksProvider(updated.status))) {
        ref.read(tasksProvider(updated.status).notifier).upsert(updated);
      }
      ref.read(lazySyncProvider.notifier).protectLocalWrite();
      ref.read(lazySyncProvider.notifier).schedule();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      ref.read(tasksProvider(widget.task.status).notifier).removeById(widget.task.id);
    }
    try {
      await _saveIfNeeded();
      await ref.read(apiProvider).updateTask(widget.task.id, spaceId: spaceId);
      ref.read(lazySyncProvider.notifier).settleWrite(widget.task.id, gen);
      ref.read(lazySyncProvider.notifier).schedule();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      ref.read(lazySyncProvider.notifier).settleWrite(widget.task.id, gen);
      if (ref.exists(tasksProvider(widget.task.status))) {
        ref.read(tasksProvider(widget.task.status).notifier).upsert(widget.task);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      ref.read(lazySyncProvider.notifier).settleWrite(widget.task.id, gen);
      if (ref.exists(tasksProvider(widget.task.status))) {
        ref.read(tasksProvider(widget.task.status).notifier).upsert(widget.task);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _moving = false);
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
          title: Text(_archived ? '归档小记' : '随手记'),
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
              children: [
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
