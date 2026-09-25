import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';
import '../widgets/priority_selector.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onOpen,
    this.onPickPriority,
    this.subtitle,
  });

  final Task task;
  final Widget? subtitle;
  final VoidCallback onOpen;

  /// 参数是优先级图标自己的 context，菜单要贴着它弹出。
  final void Function(BuildContext anchorContext)? onPickPriority;

  static const _noOverlay = WidgetStatePropertyAll(Colors.transparent);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = context.flowColors.priority(task.priority);
    final card = context.flowColors.card;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.lerp(accent, card, 0.72)!,
              Color.lerp(accent, card, 0.92)!,
              card,
            ],
            stops: const [0, 0.42, 1],
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Builder(
                  builder: (badgeContext) => InkWell(
                    onTap: onPickPriority == null
                        ? null
                        : () => onPickPriority!(badgeContext),
                    overlayColor: _noOverlay,
                    splashFactory: NoSplash.splashFactory,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.xs,
                        AppSpacing.sm,
                      ),
                      child: PriorityBadge(priority: task.priority),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onOpen,
                    overlayColor: _noOverlay,
                    splashFactory: NoSplash.splashFactory,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            DefaultTextStyle(
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(color: scheme.onSurfaceVariant),
                              child: subtitle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
