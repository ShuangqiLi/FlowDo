import { BadRequestException, Injectable } from '@nestjs/common';
import { InstanceService } from '../instance/instance.service';
import { PrismaService } from '../prisma/prisma.service';
import { TaskPriority, TaskStatus } from '../tasks/task.enums';

const PRIORITY_ORDER: Record<TaskPriority, number> = {
  HIGH: 0,
  MEDIUM: 1,
  LOW: 2,
  REMINDER: 3,
  NONE: 4,
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
    const space = await this.instance.activeSpace();
    const spaceId = space.id;
    const startOfYesterday = addDays(startOfToday, -1);

    const [todo, focus, done, archived, completedToday, completedYesterday, inboxHigh] =
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
      ]);

    const focusedTasks = [...focus].sort(comparePriorityThenRecent);
    const suggestedFocus = pickSuggestedFocus(
      focusedTasks,
      inboxHigh,
      space.focusLimit ?? DEFAULT_SUGGEST_LIMIT,
    );

    return {
      date: toDateKey(startOfToday),
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
    };
  }

  async month(year: number, month: number) {
    if (!Number.isInteger(year) || !Number.isInteger(month) || month < 1 || month > 12) {
      throw new BadRequestException('这个月份不太对');
    }
    const spaceId = await this.instance.spaceId();
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0, 23, 59, 59, 999);
    const now = new Date();
    const [completed, reminders] = await Promise.all([
      this.prisma.task.findMany({
        where: { spaceId, completedAt: { gte: start, lte: end } },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.task.findMany({
        where: {
          spaceId,
          priority: TaskPriority.REMINDER,
          remindedAt: null,
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
      const key = toDateKey(row.completedAt);
      dayCounts.set(key, (dayCounts.get(key) ?? 0) + 1);
      const list = dayTasks.get(key) ?? [];
      list.push(row);
      dayTasks.set(key, list);
    }

    const dayReminders = new Map<string, typeof reminders>();
    for (const row of reminders) {
      if (!row.remindAt || row.remindAt <= now) {
        continue;
      }
      const key = toDateKey(row.remindAt);
      if (key < toDateKey(start) || key > toDateKey(end)) {
        continue;
      }
      const list = dayReminders.get(key) ?? [];
      list.push(row);
      dayReminders.set(key, list);
    }

    const length = end.getDate();
    const days = Array.from({ length }, (_, i) => {
      const day = addDays(start, i);
      const key = toDateKey(day);
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

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function toDateKey(date: Date): string {
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, '0');
  const d = `${date.getDate()}`.padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}
