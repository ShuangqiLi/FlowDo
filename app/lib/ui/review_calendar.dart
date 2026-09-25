import 'package:flutter/material.dart';

import '../models/briefing.dart';
import '../models/task.dart';
import '../theme.dart';

typedef ReviewDayTap = void Function(BuildContext anchorContext, ReviewDay day);

/// 当月月历网格；点格子在点击位置弹出详情。
class MonthReviewCalendar extends StatelessWidget {
  const MonthReviewCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.days,
    this.todayKey,
    this.onDayTap,
  });

  final int year;
  final int month;
  final List<ReviewDay> days;
  final String? todayKey;
  final ReviewDayTap? onDayTap;

  static const _labels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byDate = {for (final d in days) d.date: d};
    final maxCount = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final first = DateTime(year, month, 1);
    final leading = (first.weekday + 6) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final cells = leading + daysInMonth;
    final rows = ((cells + 6) / 7).floor();

    return _CalendarChrome(
      child: Column(
        children: [
          Row(
            children: [
              for (final label in _labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var row = 0; row < rows; row++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _monthCell(
                        scheme,
                        index: row * 7 + col,
                        leading: leading,
                        daysInMonth: daysInMonth,
                        byDate: byDate,
                        maxCount: maxCount,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthCell(
    ColorScheme scheme, {
    required int index,
    required int leading,
    required int daysInMonth,
    required Map<String, ReviewDay> byDate,
    required int maxCount,
  }) {
    final day = index - leading + 1;
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 40);
    }
    final key =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final review = byDate[key] ?? ReviewDay(date: key, count: 0);
    return Builder(
      builder: (cellContext) => _DayCell(
        dayNumber: '$day',
        count: review.count,
        maxCount: maxCount,
        isToday: key == todayKey,
        scheme: scheme,
        onTap: onDayTap == null ? null : () => onDayTap!(cellContext, review),
      ),
    );
  }
}

class _CalendarChrome extends StatelessWidget {
  const _CalendarChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final flow = context.flowColors;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: flow.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: child,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.count,
    required this.maxCount,
    required this.isToday,
    required this.scheme,
    this.onTap,
  });

  final String dayNumber;
  final int count;
  final int maxCount;
  final bool isToday;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final intensity = maxCount <= 0 || count <= 0
        ? 0.0
        : (0.22 + 0.78 * (count / maxCount)).clamp(0.22, 1.0);
    final fill = count == 0
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
        : scheme.primary.withValues(alpha: intensity);
    final onFill = count == 0
        ? scheme.onSurfaceVariant
        : (intensity > 0.55 ? scheme.onPrimary : scheme.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: AnimatedContainer(
              duration: AppMotion.quick,
              curve: AppMotion.curve,
              height: 40,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: isToday
                    ? Border.all(color: scheme.primary, width: 1.6)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNumber,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: onFill,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                  if (count > 0)
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: onFill.withValues(alpha: 0.9),
                            fontSize: 10,
                            height: 1,
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

class ReviewSummaryRow extends StatelessWidget {
  const ReviewSummaryRow({
    super.key,
    required this.completedLabel,
    required this.completedCount,
    required this.activeLabel,
    required this.activeDays,
  });

  final String completedLabel;
  final int completedCount;
  final String activeLabel;
  final int activeDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flow = context.flowColors;
    return Material(
      color: flow.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xxs,
        ),
        child: Row(
          children: [
            _stat(context, scheme, completedLabel, completedCount),
            _stat(context, scheme, activeLabel, activeDays),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    ColorScheme scheme,
    String label,
    int value,
  ) {
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

/// 贴着被点的日期格子弹出当天完成详情。
Future<void> showReviewDayPopover(
  BuildContext anchorContext, {
  required ReviewDay day,
  required ValueChanged<Task> onOpenTask,
}) async {
  final anchor = anchorContext.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
  if (anchor == null || overlay == null || !anchor.hasSize) {
    return;
  }

  final theme = Theme.of(anchorContext);
  final scheme = theme.colorScheme;
  final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = anchor.localToGlobal(
    anchor.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final title = prettyReviewDayTitle(day.date);
  final tasks = day.tasks;

  final selected = await showMenu<Task?>(
    context: anchorContext,
    position: RelativeRect.fromLTRB(
      topLeft.dx.clamp(8.0, overlay.size.width - 240),
      bottomRight.dy + AppSpacing.xxs,
      overlay.size.width - bottomRight.dx,
      0,
    ),
    constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
    color: theme.cardColor,
    surfaceTintColor: Colors.transparent,
    elevation: 4,
    shadowColor: scheme.shadow.withValues(alpha: 0.18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.large),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    popUpAnimationStyle: AnimationStyle(
      duration: AppMotion.quick,
      curve: AppMotion.curve,
    ),
    items: [
      PopupMenuItem<Task?>(
        enabled: false,
        height: 56,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              tasks.isEmpty ? '这一天还没有搞定的事' : '搞定了 ${tasks.length} 件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      if (tasks.isEmpty)
        PopupMenuItem<Task?>(
          enabled: false,
          height: 44,
          child: Text(
            '空空的一天，也挺好。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        )
      else
        for (final task in tasks.take(8))
          PopupMenuItem<Task?>(
            value: task,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: anchorContext.flowColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
      if (tasks.length > 8)
        PopupMenuItem<Task?>(
          enabled: false,
          height: 36,
          child: Text(
            '还有 ${tasks.length - 8} 件没列完',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
    ],
  );

  if (selected != null) {
    onOpenTask(selected);
  }
}

String prettyReviewDayTitle(String iso) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (match == null) {
    return iso;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '$year年$month月$day日 ${weekdays[date.weekday - 1]}';
}
