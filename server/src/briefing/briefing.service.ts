import { Injectable } from '@nestjs/common';
import { TaskPriority, TaskStatus } from '../tasks/task.enums';
import { PrismaService } from '../prisma/prisma.service';

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
  constructor(private readonly prisma: PrismaService) {}

  async today(userId: string) {
    const now = new Date();
    const startOfToday = new Date(now);
    startOfToday.setHours(0, 0, 0, 0);
    const startOfYesterday = new Date(startOfToday);
    startOfYesterday.setDate(startOfYesterday.getDate() - 1);
    const startOfMonth = new Date(startOfToday.getFullYear(), startOfToday.getMonth(), 1);
    const endOfMonth = new Date(
      startOfToday.getFullYear(),
      startOfToday.getMonth() + 1,
      0,
      23,
      59,
      59,
      999,
    );

    const [
      todo,
      focus,
      done,
      archived,
      completedToday,
      completedYesterday,
      completedHistory,
      inboxHigh,
      me,
    ] = await Promise.all([
        this.prisma.task.count({
          where: { userId, status: TaskStatus.TODO },
        }),
        this.prisma.task.findMany({
          where: { userId, status: TaskStatus.FOCUS },
        }),
        this.prisma.task.count({
          where: { userId, status: TaskStatus.DONE },
        }),
        this.prisma.task.count({
          where: { userId, status: TaskStatus.ARCHIVED },
        }),
        this.prisma.task.findMany({
          where: {
            userId,
            completedAt: { gte: startOfToday },
          },
          orderBy: { completedAt: 'desc' },
        }),
        this.prisma.task.findMany({
          where: {
            userId,
            completedAt: { gte: startOfYesterday, lt: startOfToday },
          },
          orderBy: { completedAt: 'desc' },
        }),
        this.prisma.task.findMany({
          where: {
            userId,
            completedAt: { gte: startOfMonth, lte: endOfMonth },
          },
          orderBy: { completedAt: 'desc' },
        }),
        this.prisma.task.findMany({
          where: {
            userId,
            status: TaskStatus.TODO,
            priority: TaskPriority.HIGH,
          },
        }),
        this.prisma.user.findUnique({
          where: { id: userId },
          select: { focusLimit: true },
        }),
      ]);

    const focusedTasks = [...focus].sort(comparePriorityThenRecent);
    const suggestedFocus = pickSuggestedFocus(
      focusedTasks,
      inboxHigh,
      me?.focusLimit ?? DEFAULT_SUGGEST_LIMIT,
    );

    const dayCounts = new Map<string, number>();
    const dayTasks = new Map<string, typeof completedHistory>();
    for (const row of completedHistory) {
      if (!row.completedAt) {
        continue;
      }
      const key = toDateKey(row.completedAt);
      dayCounts.set(key, (dayCounts.get(key) ?? 0) + 1);
      const list = dayTasks.get(key) ?? [];
      list.push(row);
      dayTasks.set(key, list);
    }

    const monthDaysInMonth = endOfMonth.getDate();
    const monthDays = buildDayRange(startOfMonth, monthDaysInMonth, dayCounts, dayTasks);
    const monthCompleted = monthDays.reduce((sum, d) => sum + d.count, 0);

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
      monthReview: {
        year: startOfToday.getFullYear(),
        month: startOfToday.getMonth() + 1,
        completedCount: monthCompleted,
        activeDays: monthDays.filter((d) => d.count > 0).length,
        days: monthDays,
      },
    };
  }
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

function buildDayRange(
  start: Date,
  length: number,
  counts: Map<string, number>,
  tasksByDay: Map<string, unknown[]>,
): Array<{ date: string; count: number; tasks: unknown[] }> {
  return Array.from({ length }, (_, i) => {
    const day = addDays(start, i);
    const key = toDateKey(day);
    return {
      date: key,
      count: counts.get(key) ?? 0,
      tasks: tasksByDay.get(key) ?? [],
    };
  });
}

