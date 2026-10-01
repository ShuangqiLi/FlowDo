import { BadRequestException, Injectable } from '@nestjs/common';
import { Reminder } from '@prisma/client';
import { InstanceService } from '../instance/instance.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  lunarDayLabel,
  occurrenceKeysInMonth,
  startOfDay,
  toDateKey,
} from '../reminders/lunar-date';
import { presentReminder, toRule } from '../reminders/reminders.service';
import { TaskPriority, TaskStatus } from '../tasks/task.enums';

const PRIORITY_ORDER: Record<TaskPriority, number> = {
  HIGH: 0,
  MEDIUM: 1,
  LOW: 2,
};

const DEFAULT_SUGGEST_LIMIT = 3;

type RankedTask = { priority: string; updatedAt: Date };

export function comparePriorityThenRecent(a: RankedTask, b: RankedTask): number {
  const p =
    (PRIORITY_ORDER[a.priority as TaskPriority] ?? 9) -
    (PRIORITY_ORDER[b.priority as TaskPriority] ?? 9);
  if (p !== 0) {
    return p;
  }
  return b.updatedAt.getTime() - a.updatedAt.getTime();
}

/** 有聚焦就按优先级推荐聚焦；没有才从任务池里拿几件高优先级；都没有就空。 */
export function pickSuggestedFocus<T extends RankedTask>(
  focused: T[],
  inboxHigh: T[],
  limit = DEFAULT_SUGGEST_LIMIT,
): T[] {
  if (focused.length > 0) {
    return [...focused].sort(comparePriorityThenRecent);
  }
  return [...inboxHigh].sort(comparePriorityThenRecent).slice(0, limit);
}

@Injectable()
export class BriefingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly instance: InstanceService,
  ) {}

  async today() {
    const now = new Date();
    const startOfToday = startOfDay(now);
    const month = await this.month(
      startOfToday.getFullYear(),
      startOfToday.getMonth() + 1,
    );
    const spaceId = await this.instance.spaceId();
    const settings = await this.instance.get();
    const startOfYesterday = addDays(startOfToday, -1);

    const [todo, focus, done, archived, completedToday, completedYesterday, inboxHigh, reminders] =
      await Promise.all([
        this.prisma.task.count({ where: { spaceId, status: TaskStatus.TODO } }),
        this.prisma.task.findMany({ where: { spaceId, status: TaskStatus.FOCUS } }),
        this.prisma.task.count({ where: { spaceId, status: TaskStatus.DONE } }),
        this.prisma.task.count({ where: { spaceId, status: TaskStatus.ARCHIVED } }),
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
          where: {
            spaceId,
            status: TaskStatus.TODO,
            priority: TaskPriority.HIGH,
          },
        }),
        this.prisma.reminder.findMany({ where: { spaceId } }),
      ]);

    const focusedTasks = [...focus].sort(comparePriorityThenRecent);
    const suggestedFocus = pickSuggestedFocus(
      focusedTasks,
      inboxHigh,
      settings.focusLimit ?? DEFAULT_SUGGEST_LIMIT,
    );
    const todayKey = toDateKey(startOfToday);
    const todayReminders = reminders
      .filter((row) => toDateKey(startOfDay(row.nextDate)) <= todayKey)
      .map(presentReminder);

    return {
      date: todayKey,
      counts: {
        todo,
        focus: focusedTasks.length,
        done,
        archived,
      },
      focusedTasks,
      suggestedFocus,
      completedToday,
      completedYesterday,
      pendingArchive: done,
      todayReminders,
      monthReview: month,
    };
  }

  async month(year: number, month: number) {
    if (!Number.isInteger(year) || !Number.isInteger(month) || month < 1 || month > 12) {
      throw new BadRequestException('这个月份不太对');
    }
    const spaceId = await this.instance.spaceId();
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0, 23, 59, 59, 999);
    const [completed, reminders] = await Promise.all([
      this.prisma.task.findMany({
        where: { spaceId, completedAt: { gte: start, lte: end } },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.reminder.findMany({ where: { spaceId } }),
    ]);

    const dayCounts = new Map<string, number>();
    const dayTasks = new Map<string, typeof completed>();
    for (const row of completed) {
      if (!row.completedAt) {
        continue;
      }
      const key = toDateKey(row.completedAt);
      dayCounts.set(key, (dayCounts.get(key) ?? 0) + 1);
      const list = dayTasks.get(key) ?? [];
      list.push(row);
      dayTasks.set(key, list);
    }

    const reminderMarks = marksForMonth(reminders, year, month);
    const length = end.getDate();
    const days = Array.from({ length }, (_, i) => {
      const day = addDays(start, i);
      const key = toDateKey(day);
      return {
        date: key,
        count: dayCounts.get(key) ?? 0,
        tasks: dayTasks.get(key) ?? [],
        lunarLabel: lunarDayLabel(day),
        reminders: reminderMarks.get(key) ?? [],
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

function marksForMonth(reminders: Reminder[], year: number, month: number) {
  const marks = new Map<string, Array<{ id: string; title: string; kind: string; calendar: string }>>();
  for (const row of reminders) {
    const keys = occurrenceKeysInMonth(toRule(row), year, month);
    const mark = {
      id: row.id,
      title: row.title,
      kind: row.kind,
      calendar: row.calendar,
    };
    for (const key of keys) {
      const list = marks.get(key) ?? [];
      list.push(mark);
      marks.set(key, list);
    }
  }
  return marks;
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}
