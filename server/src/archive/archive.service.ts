import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { TaskStatus } from '../tasks/task.enums';
import { PrismaService } from '../prisma/prisma.service';

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
    const users = await this.prisma.user.findMany({
      select: { id: true, archiveAfterDays: true },
    });
    let archived = 0;
    const now = Date.now();
    for (const user of users) {
      const cutoff = new Date(
        now - user.archiveAfterDays * 24 * 60 * 60 * 1000,
      );
      const result = await this.prisma.task.updateMany({
        where: {
          userId: user.id,
          status: TaskStatus.DONE,
          completedAt: { lte: cutoff },
        },
        data: { status: TaskStatus.ARCHIVED, archivedAt: new Date() },
      });
      archived += result.count;
    }
    return archived;
  }

  async runPurge(): Promise<number> {
    const users = await this.prisma.user.findMany({
      select: { id: true, deleteArchivedAfterDays: true },
    });
    let deleted = 0;
    const now = Date.now();
    for (const user of users) {
      if (user.deleteArchivedAfterDays <= 0) {
        continue;
      }
      const cutoff = new Date(
        now - user.deleteArchivedAfterDays * 24 * 60 * 60 * 1000,
      );
      const result = await this.prisma.task.deleteMany({
        where: {
          userId: user.id,
          status: TaskStatus.ARCHIVED,
          OR: [
            { archivedAt: { lte: cutoff } },
            { archivedAt: null, updatedAt: { lte: cutoff } },
          ],
        },
      });
      deleted += result.count;
    }
    return deleted;
  }
}
