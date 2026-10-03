import 'dart:async';

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

    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        tooltip: '切换任务空间',
        style: const ButtonStyle(
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        padding: EdgeInsets.zero,
        onSelected: (value) =>
            _onSelected(context, ref, value, spaces.value ?? const []),
        itemBuilder: (context) {
        final list = spaces.value ?? const <Space>[];
        final scheme = Theme.of(context).colorScheme;
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
                    color: space.id == activeId ? scheme.primary : null,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      space.name,
                      overflow: TextOverflow.ellipsis,
                      style: space.id == activeId
                          ? TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'create',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.add_rounded, size: 20),
              title: Text('新建空间'),
            ),
          ),
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.edit_outlined, size: 20),
              title: Text('重命名'),
            ),
          ),
          if (list.length > 1)
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                title: Text('删除这个空间', style: TextStyle(color: scheme.error)),
              ),
            ),
        ];
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          shape: StadiumBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.85),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
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
        // 本地先切，缓存先亮；对账失败再滚回去。
        await switchActiveSpace(ref, id);
        return;
      } else if (value == 'create') {
        final name = await _askName(context, title: '新建任务空间', initial: '');
        if (name == null || name.isEmpty) {
          return;
        }
        final created = await api.createSpace(name);
        ref.read(spacesProvider.notifier).upsert(created);
        await switchActiveSpace(ref, created.id);
        return;
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
        final renamed = Space(id: current.id, name: name);
        ref.read(spacesProvider.notifier).upsert(renamed);
        try {
          await api.renameSpace(current.id, name);
          unawaited(ref.read(spacesProvider.notifier).reload(quiet: true));
        } catch (_) {
          ref.read(spacesProvider.notifier).upsert(current);
          rethrow;
        }
        return;
      } else if (value == 'delete') {
        final current = spaces.cast<Space?>().firstWhere(
              (space) => space?.id == activeId,
              orElse: () => null,
            );
        if (current == null) {
          return;
        }
        final count = await api.spaceTaskCount(current.id);
        if (!context.mounted) {
          return;
        }
        final taskLine = count == 0
            ? '当前空间里没有任务'
            : '当前空间里有 $count 件任务';
        final ok = await showFlowDoConfirmDialog(
          context,
          title: '删掉「${current.name}」？',
          message: '$taskLine，删除后无法找回。',
          confirmLabel: '删掉',
          destructive: true,
        );
        if (!ok) {
          return;
        }
        await api.deleteSpace(current.id);
        ref.read(spacesProvider.notifier).removeById(current.id);
        await ref.read(meProvider.notifier).reload();
        final nextId = ref.read(meProvider).value?.activeSpaceId;
        if (nextId != null) {
          final cache = ref.read(spaceSnapshotCacheProvider);
          final cached = cache.tasksFor(nextId);
          if (cached != null) {
            for (final status in taskListStatuses) {
              final list = cached[status];
              if (list != null && ref.exists(tasksProvider(status))) {
                ref.read(tasksProvider(status).notifier).replaceAll(list);
              }
            }
          } else {
            for (final status in taskListStatuses) {
              if (ref.exists(tasksProvider(status))) {
                ref.read(tasksProvider(status).notifier).replaceAll(const []);
              }
            }
          }
          final briefing = cache.briefingFor(nextId);
          if (briefing != null && ref.exists(briefingProvider)) {
            ref.read(briefingProvider.notifier).apply(briefing);
          }
        }
        unawaited(
          ref.read(lazySyncProvider.notifier).run(
                quiet: true,
                bumpCalendar: true,
              ),
        );
        return;
      }
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
