import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/briefing.dart';
import '../models/task.dart';
import '../providers.dart';
import '../theme.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: briefing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final todayKey = _todayKey();
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
                  _prettyDate(data.date),
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
                      task,
                      PriorityBadge(priority: task.priority),
                      onTap: () => _openTask(context, ref, task),
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
                      task,
                      PriorityBadge(priority: task.priority),
                      onTap: () => _openTask(context, ref, task),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  '月度回顾',
                  caption: '${data.monthReview.year}年${data.monthReview.month}月',
                ),
                ReviewSummaryRow(
                  completedLabel: '本月搞定',
                  completedCount: data.monthReview.completedCount,
                  activeLabel: '活跃天数',
                  activeDays: data.monthReview.activeDays,
                ),
                const SizedBox(height: AppSpacing.xs),
                MonthReviewCalendar(
                  year: data.monthReview.year,
                  month: data.monthReview.month,
                  days: data.monthReview.days,
                  todayKey: todayKey,
                  onDayTap: (anchor, day) => _openDay(anchor, ref, day),
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

  Future<void> _openDay(
    BuildContext anchorContext,
    WidgetRef ref,
    ReviewDay day,
  ) {
    return showReviewDayPopover(
      anchorContext,
      day: day,
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
    ref.invalidate(briefingProvider);
    ref.invalidate(tasksProvider(task.status));
  }

  /// 日历高亮用本地今天，避免服务端 UTC 日期对不齐。
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _prettyDate(String date) {
    // 今日看看抬头优先用本地今天，避免旧接口 UTC 串日。
    final local = DateTime.now();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    final DateTime dt;
    if (match != null) {
      final parsed = DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
      final sameDay = parsed.year == local.year &&
          parsed.month == local.month &&
          parsed.day == local.day;
      dt = sameDay ? parsed : local;
    } else {
      dt = local;
    }
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return '${dt.year}年${dt.month}月${dt.day}日 ${weekdays[dt.weekday - 1]}';
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
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        minVerticalPadding: AppSpacing.sm,
        onTap: onTap,
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
