import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { INSTANCE_ID } from '../instance/constants';
import { PrismaService } from '../prisma/prisma.service';
import { TaskStatus } from '../tasks/task.enums';

@Injectable()
export class ArchiveService {
  private readonly logger = new Logger(ArchiveService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async archiveDueTasks() {
    const archived = await this.runArchive();
    const deleted = await this.runPurge();
    if (archived > 0) {
      this.logger.log(`Archived ${archived} completed task(s)`);
    }
    if (deleted > 0) {
      this.logger.log(`Purged ${deleted} archived task(s)`);
    }
  }

  async runArchive(): Promise<number> {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
      select: { archiveAfterDays: true },
    });
    if (!instance) {
      return 0;
    }
    const cutoff = new Date(
      Date.now() - instance.archiveAfterDays * 24 * 60 * 60 * 1000,
    );
    const result = await this.prisma.task.updateMany({
      where: {
        status: TaskStatus.DONE,
        completedAt: { lte: cutoff },
      },
      data: { status: TaskStatus.ARCHIVED, archivedAt: new Date() },
    });
    return result.count;
  }

  async runPurge(): Promise<number> {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
      select: { deleteArchivedAfterDays: true },
    });
    if (!instance || instance.deleteArchivedAfterDays <= 0) {
      return 0;
    }
    const cutoff = new Date(
      Date.now() - instance.deleteArchivedAfterDays * 24 * 60 * 60 * 1000,
    );
    const result = await this.prisma.task.deleteMany({
      where: {
        status: TaskStatus.ARCHIVED,
        OR: [
          { archivedAt: { lte: cutoff } },
          { archivedAt: null, updatedAt: { lte: cutoff } },
        ],
      },
    });
    return result.count;
  }
}
