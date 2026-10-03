import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/briefing.dart';
import '../models/space.dart';
import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/briefing_clock_button.dart';
import '../ui/empty_state.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_page_route.dart';
import '../ui/review_calendar.dart';
import '../widgets/priority_selector.dart';
import 'task_detail_screen.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefing = ref.watch(briefingProvider);
    final calendarEpoch = ref.watch(lazySyncProvider);
    final spaces = ref.watch(spacesProvider).value ?? const <Space>[];

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: briefing.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RefreshIndicator(
          onRefresh: () => ref.read(lazySyncProvider.notifier).pull(),
          child: ListView(
            physics: refreshScrollPhysics,
            children: [
              SizedBox(
                height: 280,
                child: Center(child: Text('$e')),
              ),
            ],
          ),
        ),
        data: (data) {
          final todayKey = _todayKey();
          return ResponsiveContent(
            child: RefreshIndicator(
              onRefresh: () => ref.read(lazySyncProvider.notifier).pull(),
              child: ListView(
                physics: refreshScrollPhysics,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                children: [
                  const BriefingNowRow(),
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
                        task,
                        PriorityBadge(priority: task.priority),
                        onTap: () => _openTask(context, ref, task),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader('月度回顾', caption: '左右滑可以看别的月份'),
                  SwipeMonthCalendar(
                    key: ValueKey('month-$calendarEpoch'),
                    initial: MonthReview(
                      year: DateTime.now().year,
                      month: DateTime.now().month,
                      completedCount: 0,
                      activeDays: 0,
                      days: const [],
                    ),
                    todayKey: todayKey,
                    spaces: spaces,
                    loadMonth: (year, month) =>
                        ref.read(apiProvider).monthBriefing(year, month),
                    onDayTap: (anchor, day) => _openDay(anchor, ref, day),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _BriefingTotals(data: data),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDay(
    BuildContext anchorContext,
    WidgetRef ref,
    ReviewDay day,
  ) {
    return showReviewDayPopover(
      anchorContext,
      day: day,
      spaces: ref.read(spacesProvider).value ?? const [],
      onOpenTask: (task) => _openTask(anchorContext, ref, task),
    );
  }

  Future<void> _openTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    await Navigator.of(context).push(
      FlowDoPageRoute(
        swipeFromLeftEdgeOnly: false,
        builder: (_) => TaskDetailScreen(task: task),
      ),
    );
    ref.read(lazySyncProvider.notifier).schedule();
  }

  /// 日历高亮用本地今天，避免服务端 UTC 日期对不齐。
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Widget _taskTile(
    BuildContext context,
    Task task,
    Widget leading, {
    VoidCallback? onTap,
  }) {
    return FlowDoCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: leading,
        title: Text(task.title),
        trailing:
            onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        minVerticalPadding: AppSpacing.sm,
        onTap: onTap,
      ),
    );
  }
}

class _BriefingTotals extends StatelessWidget {
  const _BriefingTotals({required this.data});

  final Briefing data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        FlowDoCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '全部空间 · ${data.totalCount} 件',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _stat(context, '任务池', data.todoCount),
                  _stat(context, '聚焦', data.focusCount),
                  _stat(context, '完成', data.doneCount),
                  _stat(context, '归档', data.archivedCount),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '待提醒 ${data.reminderCount} · 今天完成 ${data.completedToday.length} · 昨天完成 ${data.completedYesterday.length}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (data.spaces.length > 1) ...[
          const SizedBox(height: AppSpacing.xs),
          FlowDoCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                for (var i = 0; i < data.spaces.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _spaceRow(context, data.spaces[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _spaceRow(BuildContext context, SpaceBriefing space) {
    final color = AppThemeKey.fromKey(space.themeKey).preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                space.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              '共 ${space.total} 件',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '池 ${space.todo} · 焦 ${space.focus} · 完 ${space.done} · 归 ${space.archived} · 提 ${space.reminders} · 今 ${space.completedToday} · 昨 ${space.completedYesterday}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.9),
                height: 1.35,
              ),
        ),
      ],
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
