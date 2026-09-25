import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_dialog.dart';
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
  bool _deleted = false;
  bool _saving = false;

  static const _statusLabels = {
    'TODO': '待办',
    'FOCUS': '聚焦',
    'DONE': '完成',
    'ARCHIVED': '归档',
  };

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

  bool get _canDelete => widget.task.status == 'TODO' || widget.task.status == 'ARCHIVED';

  Future<void> _saveIfNeeded() async {
    if (_deleted || _saving || !_dirty || _archived) {
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }
    _saving = true;
    try {
      await ref.read(apiProvider).updateTask(
            widget.task.id,
            title: title,
            body: _body.text,
          );
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

  Future<void> _confirmDelete() async {
    final archived = _archived;
    final ok = await showFlowDoConfirmDialog(
      context,
      title: archived ? '清掉这条归档？' : '不做了？',
      message: archived ? '删掉就回不来啦。' : '会从任务池里拿走，回不来哦。',
      confirmLabel: '删掉',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    _deleted = true;
    await ref.read(apiProvider).deleteTask(widget.task.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusLabel = _statusLabels[widget.task.status] ?? widget.task.status;

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
            if (_canDelete)
              IconButton(
                tooltip: _archived ? '清掉' : '先不做了',
                icon: const Icon(Icons.delete_outline),
                onPressed: _confirmDelete,
              ),
          ],
        ),
        body: ResponsiveContent(
          maxWidth: AppLayout.readingMaxWidth,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
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
              FlowDoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    PriorityBadge(priority: widget.task.priority),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FlowDoCard(
                child: TextField(
                  controller: _body,
                  readOnly: _archived,
                  minLines: 10,
                  maxLines: 24,
                  decoration: InputDecoration(
                    labelText: '过程小记',
                    hintText: _archived ? null : '想到什么就记一笔（可选）',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              if (_archived) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '这条已经收进归档，只能看看。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
