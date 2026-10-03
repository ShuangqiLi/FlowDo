import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/notice.dart';
import '../models/task.dart';
import '../providers.dart';
import '../screens/task_detail_screen.dart';
import '../theme.dart';
import 'flowdo_page_route.dart';

/// 右上角通知。有未读时亮红点，点开是一份弹出菜单。
class NoticeButton extends ConsumerWidget {
  const NoticeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final notices = ref.watch(noticesProvider).asData?.value ?? const <Notice>[];
    final unread = notices.where((notice) => notice.unread).length;
    final tooltip = unread == 0 ? '通知' : '通知，$unread 条未读';

    return IconButton(
      tooltip: tooltip,
      onPressed: () => _open(context, ref, notices),
      style: const ButtonStyle(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        minimumSize: WidgetStatePropertyAll(Size(44, 44)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        smallSize: 8,
        backgroundColor: scheme.error,
        child: Icon(
          unread > 0
              ? Icons.notifications_rounded
              : Icons.notifications_outlined,
          color: scheme.onSurface,
          semanticLabel: tooltip,
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    List<Notice> notices,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.hasSize) {
      return;
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final selected = await showMenu<Notice>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy + AppSpacing.xxs,
        overlay.size.width - bottomRight.dx,
        0,
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      color: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      popUpAnimationStyle: AnimationStyle(
        duration: AppMotion.quick,
        curve: AppMotion.curve,
      ),
      items: [
        if (notices.isEmpty)
          PopupMenuItem<Notice>(
            enabled: false,
            child: Text(
              '还没有通知',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final notice in notices.take(12))
            PopupMenuItem<Notice>(
              value: notice.taskId == null ? null : notice,
              height: 64,
              child: _NoticeRow(notice: notice),
            ),
      ],
    );
    await ref.read(noticesProvider.notifier).markRead();
    if (selected == null || !context.mounted) {
      return;
    }
    final task = _findTask(ref, selected.taskId!);
    if (task == null) {
      return;
    }
    await Navigator.of(context).push(
      FlowDoPageRoute(builder: (_) => TaskDetailScreen(task: task)),
    );
  }

  Task? _findTask(WidgetRef ref, String id) {
    for (final status in taskListStatuses) {
      final list = ref.read(tasksProvider(status)).asData?.value;
      if (list == null) {
        continue;
      }
      for (final task in list) {
        if (task.id == id) {
          return task;
        }
      }
    }
    return null;
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = DateFormat('M月d日 HH:mm').format(notice.createdAt.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          notice.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: notice.unread ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          '${notice.message} · $when',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
