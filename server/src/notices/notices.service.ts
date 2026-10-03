import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { InstanceService } from '../instance/instance.service';
import { PrismaService } from '../prisma/prisma.service';
import { advanceReminder } from '../tasks/reminder-time';
import { RemindRepeat, TaskPriority, TaskStatus } from '../tasks/task.enums';

@Injectable()
export class NoticesService implements OnModuleInit {
  private readonly logger = new Logger(NoticesService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly instance: InstanceService,
  ) {}

  onModuleInit(): void {
    void this.promoteDue();
  }

  @Interval(15_000)
  async promoteDue(): Promise<void> {
    if (this.running) {
      return;
    }
    this.running = true;
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
    } finally {
      this.running = false;
    }
  }

  async list() {
    const spaceId = await this.instance.spaceId();
    return this.prisma.notice.findMany({
      where: { spaceId },
      orderBy: { createdAt: 'desc' },
      take: 30,
    });
  }

  async markRead() {
    const spaceId = await this.instance.spaceId();
    await this.prisma.notice.updateMany({
      where: { spaceId, readAt: null },
      data: { readAt: new Date() },
    });
    return { ok: true };
  }

  async clear() {
    const spaceId = await this.instance.spaceId();
    await this.prisma.notice.deleteMany({ where: { spaceId } });
    return { ok: true };
  }
}
