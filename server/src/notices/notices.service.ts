import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { advanceReminder } from '../tasks/reminder-time';
import { RemindRepeat, TaskPriority, TaskStatus } from '../tasks/task.enums';

@Injectable()
export class NoticesService implements OnModuleInit {
  private readonly logger = new Logger(NoticesService.name);
  private run: Promise<void> | null = null;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit(): void {
    void this.promoteDue();
  }

  @Interval(15_000)
  async promoteDue(): Promise<void> {
    if (this.run) {
      return this.run;
    }
    this.run = this.doPromote().finally(() => {
      this.run = null;
    });
    return this.run;
  }

  private async doPromote(): Promise<void> {
    try {
      const now = new Date();
      const due = await this.prisma.task.findMany({
        where: {
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          remindAt: { lte: now },
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
        },
      });
      for (const task of due) {
        if (!task.remindAt) {
          continue;
        }
        const repeating = task.remindRepeat !== RemindRepeat.ONCE;
        await this.prisma.$transaction(async (tx) => {
          if (!repeating) {
            await tx.task.update({
              where: { id: task.id },
              data: {
                status: TaskStatus.FOCUS,
                remindedAt: now,
                completedAt: null,
                archivedAt: null,
              },
            });
            await tx.notice.create({
              data: {
                spaceId: task.spaceId,
                taskId: task.id,
                title: task.title,
                message: '到点了，已经放进聚焦',
              },
            });
            return;
          }
          const clone = await tx.task.create({
            data: {
              spaceId: task.spaceId,
              title: task.title,
              body: task.body,
              status: TaskStatus.FOCUS,
              priority: TaskPriority.REMINDER,
              remindAt: task.remindAt,
              remindRepeat: RemindRepeat.ONCE,
              remindedAt: now,
            },
          });
          await tx.task.update({
            where: { id: task.id },
            data: {
              status: TaskStatus.TODO,
              remindAt: advanceReminder(
                task.remindAt!,
                task.remindRepeat as RemindRepeat,
                now,
                {
                  cron: task.remindCron,
                  lunar: task.remindLunar,
                },
              ),
              remindedAt: null,
              completedAt: null,
              archivedAt: null,
            },
          });
          await tx.notice.create({
            data: {
              spaceId: task.spaceId,
              taskId: clone.id,
              title: task.title,
              message: '到点了，已经放进聚焦',
            },
          });
        });
      }
      if (due.length > 0) {
        this.logger.log(`提醒了 ${due.length} 件任务`);
      }
    } catch (error) {
      const text = error instanceof Error ? error.message : String(error);
      this.logger.warn(`提醒检查失败：${text}`);
    }
  }

  async list() {
    await this.promoteDue();
    const [rows, pending] = await Promise.all([
      this.prisma.notice.findMany({
        include: { space: { select: { name: true, themeKey: true } } },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.task.findMany({
        where: {
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          remindAt: { not: null },
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
        },
        include: { space: { select: { name: true, themeKey: true } } },
        orderBy: { remindAt: 'asc' },
        take: 40,
      }),
    ]);
    return {
      notices: rows.map((row) => ({
        id: row.id,
        taskId: row.taskId,
        title: row.title,
        message: row.message,
        createdAt: row.createdAt,
        readAt: row.readAt,
        spaceId: row.spaceId,
        spaceName: row.space.name,
        spaceThemeKey: row.space.themeKey,
      })),
      pending: pending
        .filter((task) => task.remindAt != null)
        .map((task) => ({
          id: task.id,
          title: task.title,
          spaceId: task.spaceId,
          spaceName: task.space.name,
          spaceThemeKey: task.space.themeKey,
          remindAt: task.remindAt,
          remindRepeat: task.remindRepeat,
          status: task.status,
        })),
    };
  }

  async markRead() {
    await this.prisma.notice.updateMany({
      where: { readAt: null },
      data: { readAt: new Date() },
    });
    return { ok: true };
  }

  async clear() {
    await this.prisma.notice.deleteMany();
    return { ok: true };
  }
}
