import { BadRequestException, Injectable } from '@nestjs/common';
import {
  daysInMonth,
  DEFAULT_TZ_OFFSET_MINUTES,
  monthDateKey,
  monthRange,
  startOfZonedDay,
  toDateKey,
} from '../clock/zone';
import { InstanceService } from '../instance/instance.service';
import { PrismaService } from '../prisma/prisma.service';
import { reminderMarks } from '../tasks/reminder-time';
import { comparePriorityThenRecent } from '../tasks/priority-order';
import { RemindRepeat, TaskPriority, TaskStatus } from '../tasks/task.enums';

const DEFAULT_SUGGEST_LIMIT = 3;

type RankedTask = { priority: string; updatedAt: Date };

export { comparePriorityThenRecent };

/** 有聚焦就按优先级推荐聚焦；没有才从任务池里拿几件高优先级；都没有就空。 */
export function pickSuggestedFocus<T extends RankedTask>(
  focused: T[],
  inboxHigh: T[],
  limit = DEFAULT_SUGGEST_LIMIT,
): T[] {
  if (focused.length > 0) {
    return [...focused].sort((a, b) =>
      comparePriorityThenRecent(a, b, TaskStatus.FOCUS),
    );
  }
  return [...inboxHigh]
    .sort((a, b) => comparePriorityThenRecent(a, b, TaskStatus.TODO))
    .slice(0, limit);
}

@Injectable()
export class BriefingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly instance: InstanceService,
  ) {}

  async today(tzOffset = DEFAULT_TZ_OFFSET_MINUTES) {
    const now = new Date();
    const startOfToday = startOfZonedDay(now, tzOffset);
    const space = await this.instance.activeSpace();
    const spaceId = space.id;
    const startOfYesterday = new Date(
      startOfToday.getTime() - 24 * 60 * 60 * 1000,
    );

    const [
      todo,
      focus,
      done,
      archived,
      reminderCount,
      completedToday,
      completedYesterday,
      focused,
      inboxHigh,
    ] = await Promise.all([
      this.prisma.task.count({
        where: { spaceId, status: TaskStatus.TODO },
      }),
      this.prisma.task.count({
        where: { spaceId, status: TaskStatus.FOCUS },
      }),
      this.prisma.task.count({
        where: { spaceId, status: TaskStatus.DONE },
      }),
      this.prisma.task.count({
        where: { spaceId, status: TaskStatus.ARCHIVED },
      }),
      this.prisma.task.count({
        where: {
          spaceId,
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
          remindAt: { gt: now },
        },
      }),
      this.prisma.task.findMany({
        where: { spaceId, completedAt: { gte: startOfToday } },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.task.findMany({
        where: {
          spaceId,
          completedAt: { gte: startOfYesterday, lt: startOfToday },
        },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.task.findMany({
        where: { spaceId, status: TaskStatus.FOCUS },
      }),
      this.prisma.task.findMany({
        where: {
          spaceId,
          status: TaskStatus.TODO,
          priority: TaskPriority.HIGH,
        },
      }),
    ]);

    const focusedTasks = [...focused].sort((a, b) =>
      comparePriorityThenRecent(a, b, TaskStatus.FOCUS),
    );
    const suggestedFocus = pickSuggestedFocus(
      focusedTasks,
      inboxHigh,
      space.focusLimit ?? DEFAULT_SUGGEST_LIMIT,
    );

    return {
      date: toDateKey(now, tzOffset),
      counts: {
        todo,
        focus,
        done,
        archived,
        reminders: reminderCount,
        completedToday: completedToday.length,
        completedYesterday: completedYesterday.length,
      },
      focusedTasks,
      suggestedFocus,
      completedToday,
      completedYesterday,
      pendingArchive: done,
    };
  }

  async month(
    year: number,
    month: number,
    tzOffset = DEFAULT_TZ_OFFSET_MINUTES,
  ) {
    if (
      !Number.isInteger(year) ||
      !Number.isInteger(month) ||
      month < 1 ||
      month > 12
    ) {
      throw new BadRequestException('这个月份不太对');
    }
    const spaceId = await this.instance.spaceId();
    const { start, end } = monthRange(year, month, tzOffset);
    const now = new Date();
    const startKey = monthDateKey(year, month, 1);
    const endKey = monthDateKey(year, month, daysInMonth(year, month));
    const [completed, repeating, once] = await Promise.all([
      this.prisma.task.findMany({
        where: { spaceId, completedAt: { gte: start, lte: end } },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.task.findMany({
        where: {
          spaceId,
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          remindRepeat: { not: RemindRepeat.ONCE },
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
          remindAt: { lte: end },
        },
        orderBy: { remindAt: 'asc' },
      }),
      this.prisma.task.findMany({
        where: {
          spaceId,
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          remindRepeat: RemindRepeat.ONCE,
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
          remindAt: { gt: now, lte: end },
        },
        orderBy: { remindAt: 'asc' },
      }),
    ]);

    const dayCounts = new Map<string, number>();
    const dayTasks = new Map<string, typeof completed>();
    for (const row of completed) {
      if (!row.completedAt) {
        continue;
      }
      const key = toDateKey(row.completedAt, tzOffset);
      dayCounts.set(key, (dayCounts.get(key) ?? 0) + 1);
      const list = dayTasks.get(key) ?? [];
      list.push(row);
      dayTasks.set(key, list);
    }

    const dayReminders = new Map<string, Array<(typeof once)[number]>>();
    const putReminder = (row: (typeof once)[number], at: Date) => {
      const key = toDateKey(at, tzOffset);
      if (key < startKey || key > endKey) {
        return;
      }
      const list = dayReminders.get(key) ?? [];
      list.push({ ...row, remindAt: at });
      dayReminders.set(key, list);
    };
    for (const row of once) {
      if (row.remindAt) {
        putReminder(row, row.remindAt);
      }
    }
    for (const row of repeating) {
      if (!row.remindAt) {
        continue;
      }
      for (const at of reminderMarks(
        row.remindAt,
        row.remindRepeat as RemindRepeat,
        start,
        end,
        now,
        {
          cron: row.remindCron,
          lunar: row.remindLunar,
          tzOffsetMinutes: tzOffset,
        },
      )) {
        putReminder(row, at);
      }
    }

    const length = daysInMonth(year, month);
    const days = Array.from({ length }, (_, i) => {
      const key = monthDateKey(year, month, i + 1);
      return {
        date: key,
        count: dayCounts.get(key) ?? 0,
        tasks: dayTasks.get(key) ?? [],
        reminders: dayReminders.get(key) ?? [],
      };
    });

    return {
      year,
      month,
      completedCount: days.reduce((sum, day) => sum + day.count, 0),
      activeDays: days.filter((day) => day.count > 0).length,
      days,
    };
  }
}
