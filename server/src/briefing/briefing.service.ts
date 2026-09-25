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
    const startOfWeek = new Date(startOfToday);
    const weekday = startOfWeek.getDay();
    const daysFromMonday = weekday === 0 ? 6 : weekday - 1;
    startOfWeek.setDate(startOfWeek.getDate() - daysFromMonday);

    const [
      todo,
      focus,
      done,
      archived,
      completedToday,
      completedYesterday,
      completedThisWeek,
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
            completedAt: { gte: startOfWeek },
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

    return {
      date: startOfToday.toISOString().slice(0, 10),
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
      completedThisWeek,
      pendingArchive: done,
    };
  }
}

