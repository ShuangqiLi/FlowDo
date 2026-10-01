import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/space.dart';
import '../providers.dart';
import 'flowdo_dialog.dart';

/// 左上角任务空间：点开后切换、新建、重命名或删除。
class SpaceSwitcher extends ConsumerWidget {
  const SpaceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(spacesProvider);
    final activeId = ref.watch(meProvider).value?.activeSpaceId;
    final name = spaces.maybeWhen(
      data: (list) {
        for (final space in list) {
          if (space.id == activeId) {
            return space.name;
          }
        }
        return list.isEmpty ? '任务空间' : list.first.name;
      },
      orElse: () => '任务空间',
    );

    return PopupMenuButton<String>(
      tooltip: '切换任务空间',
      onSelected: (value) => _onSelected(context, ref, value, spaces.value ?? const []),
      itemBuilder: (context) {
        final list = spaces.value ?? const <Space>[];
        return [
          for (final space in list)
            PopupMenuItem(
              value: 'switch:${space.id}',
              child: Row(
                children: [
                  Icon(
                    space.id == activeId
                        ? Icons.check_rounded
                        : Icons.circle_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(space.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'create', child: Text('新建空间')),
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          if (list.length > 1)
            const PopupMenuItem(value: 'delete', child: Text('删除这个空间')),
        ];
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_outlined, size: 20),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded),
        ],
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
    List<Space> spaces,
  ) async {
    final api = ref.read(apiProvider);
    final activeId = ref.read(meProvider).value?.activeSpaceId;
    try {
      if (value.startsWith('switch:')) {
        final id = value.substring('switch:'.length);
        if (id == activeId) {
          return;
        }
        await api.updateMe(activeSpaceId: id);
      } else if (value == 'create') {
        final name = await _askName(context, title: '新建任务空间', initial: '');
        if (name == null || name.isEmpty) {
          return;
        }
        final created = await api.createSpace(name);
        await api.updateMe(activeSpaceId: created.id);
      } else if (value == 'rename') {
        final current = spaces.cast<Space?>().firstWhere(
              (space) => space?.id == activeId,
              orElse: () => spaces.isEmpty ? null : spaces.first,
            );
        if (current == null) {
          return;
        }
        final name = await _askName(context, title: '重命名', initial: current.name);
        if (name == null || name.isEmpty || name == current.name) {
          return;
        }
        await api.renameSpace(current.id, name);
      } else if (value == 'delete') {
        final current = spaces.cast<Space?>().firstWhere(
              (space) => space?.id == activeId,
              orElse: () => null,
            );
        if (current == null) {
          return;
        }
        final ok = await showFlowDoConfirmDialog(
          context,
          title: '删掉「${current.name}」？',
          message: '这个空间里的任务和提醒会一起删掉，回不来。',
          confirmLabel: '删掉',
          destructive: true,
        );
        if (!ok) {
          return;
        }
        await api.deleteSpace(current.id);
      }
      ref.invalidate(meProvider);
      ref.invalidate(spacesProvider);
      ref.invalidate(briefingProvider);
      ref.invalidate(tasksProvider('TODO'));
      ref.invalidate(tasksProvider('FOCUS'));
      ref.invalidate(tasksProvider('DONE'));
      ref.invalidate(tasksProvider('ARCHIVED'));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '名称'),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('好'),
            ),
          ],
        );
      },
    );
  }
}
