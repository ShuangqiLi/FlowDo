import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';
import '../widgets/priority_selector.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onOpen,
    required this.actions,
    this.onPickPriority,
    this.subtitle,
  });

  final Task task;
  final Widget? subtitle;
  final VoidCallback onOpen;

  /// 参数是优先级图标自己的 context，菜单要贴着它弹出。
  final void Function(BuildContext anchorContext)? onPickPriority;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = context.flowColors.priority(task.priority);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.055),
              context.flowColors.card,
            ],
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Builder(
                  builder: (badgeContext) => InkWell(
                    onTap: onPickPriority == null ? null : () => onPickPriority!(badgeContext),
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
              ...actions,
              const SizedBox(width: AppSpacing.xxs),
            ],
          ),
        ),
      ),
    );
  }
}
