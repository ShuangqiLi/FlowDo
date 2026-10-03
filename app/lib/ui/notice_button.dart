import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/notice.dart';
import '../models/task.dart';
import '../providers.dart';
import '../screens/task_detail_screen.dart';
import '../theme.dart';
import 'flowdo_page_route.dart';

/// 右上角通知。有未读时亮红点，点开是一份贴着按钮的卡片列表。
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
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final selected = await Navigator.of(context).push<Object>(
      _NoticePanelRoute(
        position: RelativeRect.fromLTRB(
          topLeft.dx,
          bottomRight.dy + AppSpacing.xxs,
          overlay.size.width - bottomRight.dx,
          0,
        ),
        notices: notices,
      ),
    );
    if (selected == _clearNotices) {
      await ref.read(noticesProvider.notifier).clear();
      return;
    }
    await ref.read(noticesProvider.notifier).markRead();
    if (selected is! Notice || selected.taskId == null || !context.mounted) {
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

class _ClearNotices {
  const _ClearNotices();
}

const _clearNotices = _ClearNotices();

/// 通知列表。只写任务标题和触发时间。
class NoticePanel extends StatelessWidget {
  const NoticePanel({
    super.key,
    required this.notices,
    required this.onOpen,
    required this.onClear,
  });

  final List<Notice> notices;
  final ValueChanged<Notice> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flow = context.flowColors;
    return Material(
      color: flow.canvas,
      elevation: 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: notices.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  '暂无通知',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  const buttonHeight = 44.0;
                  final listMax = (constraints.maxHeight -
                          buttonHeight -
                          AppSpacing.sm)
                      .clamp(72.0, constraints.maxHeight);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: listMax),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: notices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final notice = notices[index];
                            return _NoticeCard(
                              key: ValueKey(notice.id),
                              notice: notice,
                              onTap: () => onOpen(notice),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton(
                        onPressed: onClear,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          minimumSize: const Size.fromHeight(buttonHeight),
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          disabledBackgroundColor:
                              scheme.error.withValues(alpha: 0.38),
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        child: const Text('清空'),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({super.key, required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = DateFormat('M月d日 HH:mm').format(notice.createdAt.toLocal());
    return Semantics(
      button: true,
      label: '${notice.title}，$when',
      excludeSemantics: true,
      child: Material(
        color: context.flowColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: notice.unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    when,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticePanelRoute extends PopupRoute<Object> {
  _NoticePanelRoute({required this.position, required this.notices});

  final RelativeRect position;
  final List<Notice> notices;

  @override
  Duration get transitionDuration => AppMotion.quick;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => '关闭通知';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: _NoticePanelLayout(position),
      child: NoticePanel(
        notices: notices,
        onOpen: (notice) => Navigator.of(context).pop(notice),
        onClear: () => Navigator.of(context).pop(_clearNotices),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.curve),
      child: child,
    );
  }
}

class _NoticePanelLayout extends SingleChildLayoutDelegate {
  _NoticePanelLayout(this.position);

  final RelativeRect position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxHeight = (constraints.maxHeight - position.top - AppSpacing.xs)
        .clamp(120.0, constraints.maxHeight);
    return BoxConstraints(maxWidth: 320, maxHeight: maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rawLeft = size.width - position.right - childSize.width;
    final maxLeft = (size.width - childSize.width - AppSpacing.xs)
        .clamp(AppSpacing.xs, double.infinity);
    final left = rawLeft.clamp(AppSpacing.xs, maxLeft);
    final top = position.top.clamp(
      AppSpacing.xs,
      size.height - childSize.height - AppSpacing.xs,
    );
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _NoticePanelLayout oldDelegate) {
    return position != oldDelegate.position;
  }
}
