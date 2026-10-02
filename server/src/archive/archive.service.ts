import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
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
    const spaces = await this.prisma.space.findMany({
      select: { id: true, archiveAfterDays: true },
    });
    let total = 0;
    const now = Date.now();
    for (const space of spaces) {
      const cutoff = new Date(now - space.archiveAfterDays * 24 * 60 * 60 * 1000);
      const result = await this.prisma.task.updateMany({
        where: {
          spaceId: space.id,
          status: TaskStatus.DONE,
          completedAt: { lte: cutoff },
        },
        data: { status: TaskStatus.ARCHIVED, archivedAt: new Date() },
      });
      total += result.count;
    }
    return total;
  }

  async runPurge(): Promise<number> {
    const spaces = await this.prisma.space.findMany({
      select: { id: true, deleteArchivedAfterDays: true },
    });
    let total = 0;
    const now = Date.now();
    for (const space of spaces) {
      if (space.deleteArchivedAfterDays <= 0) {
        continue;
      }
      const cutoff = new Date(
        now - space.deleteArchivedAfterDays * 24 * 60 * 60 * 1000,
      );
      const result = await this.prisma.task.deleteMany({
        where: {
          spaceId: space.id,
          status: TaskStatus.ARCHIVED,
          OR: [
            { archivedAt: { lte: cutoff } },
            { archivedAt: null, updatedAt: { lte: cutoff } },
          ],
        },
      });
      total += result.count;
    }
    return total;
  }
}
