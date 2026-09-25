import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import '../ui/empty_state.dart';
import '../ui/flowdo_card.dart';
import '../widgets/priority_selector.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefing = ref.watch(briefingProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: briefing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          return ResponsiveContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                Text(
                  data.date,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader('可以先做这些', caption: '挑一件顺手的，就算开始。'),
                if (data.suggestedFocus.isEmpty)
                  const EmptyState(
                    icon: Icons.lightbulb_rounded,
                    message: '暂时没什么特别推荐，\n去任务池随便挑一件吧。',
                  )
                else
                  ...data.suggestedFocus.map(
                    (task) => _taskTile(
                      context,
                      task.title,
                      PriorityBadge(priority: task.priority),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader('正在聚焦'),
                if (data.focusedTasks.isEmpty)
                  Text(
                    '手头还空着，挑一件放进来吧。',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  ...data.focusedTasks.map(
                    (task) => _taskTile(
                      context,
                      task.title,
                      PriorityBadge(priority: task.priority),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader('本周搞定了'),
                if (data.completedThisWeek.isEmpty)
                  Text(
                    '本周还没打卡，没关系，慢慢来。',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  ...data.completedThisWeek.map(
                    (task) => _taskTile(
                      context,
                      task.title,
                      Icon(
                        Icons.check_circle_rounded,
                        color: context.flowColors.success,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FlowDoCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.xxs,
                  ),
                  child: Row(
                    children: [
                      _stat(context, '任务池', data.todoCount),
                      _stat(context, '聚焦', data.focusCount),
                      _stat(context, '完成', data.doneCount),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '今天搞定 ${data.completedToday.length} · 昨天搞定 ${data.completedYesterday.length}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _taskTile(BuildContext context, String title, Widget leading) {
    return FlowDoCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: leading,
        title: Text(title),
        minVerticalPadding: AppSpacing.sm,
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
