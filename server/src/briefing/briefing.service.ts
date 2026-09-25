import { Injectable } from '@nestjs/common';
import { TaskPriority, TaskStatus } from '../tasks/task.enums';
import { PrismaService } from '../prisma/prisma.service';

const PRIORITY_ORDER: Record<TaskPriority, number> = {
  HIGH: 0,
  MEDIUM: 1,
  LOW: 2,
};

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
      ]);

    const focusedTasks = [...focus].sort((a, b) => {
      const p = PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority];
      if (p !== 0) {
        return p;
      }
      return b.updatedAt.getTime() - a.updatedAt.getTime();
    });

    const suggestedFocus = focusedTasks.filter(
      (t) => t.priority === TaskPriority.HIGH,
    );
    const suggestedTasks =
      suggestedFocus.length > 0
        ? suggestedFocus
        : [...inboxHigh].sort(
            (a, b) => b.updatedAt.getTime() - a.updatedAt.getTime(),
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
      suggestedFocus: suggestedTasks,
      completedToday,
      completedYesterday,
      completedThisWeek,
      pendingArchive: done,
    };
  }
}
