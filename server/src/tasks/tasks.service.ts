import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { InstanceService } from '../instance/instance.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTaskDto, UpdateTaskDto } from './dto/task.dto';
import { TaskPriority, TaskStatus } from './task.enums';
import { parseReminderInstant } from './reminder-time';
import { canTransition } from './task-status';

const PRIORITY_ORDER: Record<TaskPriority, number> = {
  HIGH: 0,
  MEDIUM: 1,
  LOW: 2,
  REMINDER: 3,
  NONE: 4,
};

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly instance: InstanceService,
  ) {}

  async list(status?: TaskStatus) {
    const spaceId = await this.instance.spaceId();
    const where: Prisma.TaskWhereInput = { spaceId };
    if (status) {
      where.status = status;
    }
    const tasks = await this.prisma.task.findMany({
      where,
      orderBy: [{ updatedAt: 'desc' }],
    });
    return [...tasks].sort((a, b) => {
      const p = PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority];
      if (p !== 0) {
        return p;
      }
      return b.updatedAt.getTime() - a.updatedAt.getTime();
    });
  }

  async create(dto: CreateTaskDto) {
    const spaceId = await this.instance.spaceId();
    return this.prisma.task.create({
      data: {
        spaceId,
        title: dto.title.trim(),
        body: dto.body?.trim() ? dto.body.trim() : null,
        priority: dto.priority ?? TaskPriority.NONE,
        remindAt: reminderForCreate(dto.priority, dto.remindAt),
        status: TaskStatus.TODO,
      },
    });
  }

  async update(id: string, dto: UpdateTaskDto) {
    // 换空间时任务可能已不在当前空间，所以按 id 查。
    const task = await this.prisma.task.findFirst({ where: { id } });
    if (!task) {
      throw new NotFoundException('这条任务找不到了');
    }
    if (task.status === TaskStatus.ARCHIVED) {
      throw new BadRequestException('归档的任务只能看，不能改啦');
    }

    const data: Prisma.TaskUpdateInput = {};
    if (dto.title !== undefined) {
      data.title = dto.title.trim();
    }
    if (dto.body !== undefined) {
      data.body = dto.body === null || dto.body.trim() === '' ? null : dto.body;
    }
    if (dto.priority !== undefined) {
      data.priority = dto.priority;
    }
    applyReminder(task, dto, data);

    let nextSpaceId = task.spaceId;
    if (dto.spaceId !== undefined && dto.spaceId !== task.spaceId) {
      const target = await this.prisma.space.findUnique({
        where: { id: dto.spaceId },
      });
      if (!target) {
        throw new BadRequestException('这个任务空间找不到了');
      }
      data.space = { connect: { id: target.id } };
      nextSpaceId = target.id;
    }

    if (dto.status !== undefined && dto.status !== task.status) {
      if (!canTransition(task.status, dto.status)) {
        throw new BadRequestException('这条任务现在不能改成那个状态');
      }
      data.status = dto.status;
      if (dto.status === TaskStatus.DONE) {
        data.completedAt = new Date();
        data.archivedAt = null;
      } else if (
        dto.status === TaskStatus.TODO ||
        dto.status === TaskStatus.FOCUS
      ) {
        data.completedAt = null;
        data.archivedAt = null;
      } else if (dto.status === TaskStatus.ARCHIVED) {
        data.archivedAt = new Date();
      }
    }

    const enteringFocus =
      dto.status === TaskStatus.FOCUS && task.status !== TaskStatus.FOCUS;
    const movingWhileFocused =
      nextSpaceId !== task.spaceId &&
      task.status === TaskStatus.FOCUS &&
      (dto.status === undefined || dto.status === TaskStatus.FOCUS);
    if (!enteringFocus && !movingWhileFocused) {
      return this.prisma.task.update({ where: { id }, data });
    }

    const space = await this.prisma.space.findUnique({
      where: { id: nextSpaceId },
    });
    const limit = space?.focusLimit ?? 3;
    const fullMessage =
      movingWhileFocused && !enteringFocus
        ? `那边聚焦已经满了（${limit} 件），先腾出位子再搬过去。`
        : `手头这 ${limit} 件先盯紧啦。搞定或先放回任务池，再接新的。`;
    // 锁住空间这一行，慢网下同时送进来的几条才会按顺序占名额。
    // id 在库里是文本，不能转成 uuid，否则 Postgres 直接 500。
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`
        SELECT "id" FROM "Space" WHERE "id" = ${nextSpaceId} FOR UPDATE
      `;
      const focused = await tx.task.count({
        where: { spaceId: nextSpaceId, status: TaskStatus.FOCUS },
      });
      if (focused >= limit) {
        throw new BadRequestException(fullMessage);
      }
      return tx.task.update({ where: { id }, data });
    });
  }

  async remove(id: string) {
    const spaceId = await this.instance.spaceId();
    const task = await this.prisma.task.findFirst({ where: { id, spaceId } });
    if (!task) {
      throw new NotFoundException('这条任务找不到了');
    }
    if (
      task.status !== TaskStatus.TODO &&
      task.status !== TaskStatus.ARCHIVED
    ) {
      throw new BadRequestException(
        '现在还不能删这条，先放回任务池或归档再说',
      );
    }
    await this.prisma.task.delete({ where: { id } });
    return { ok: true };
  }
}

function reminderForCreate(
  priority: TaskPriority | undefined,
  remindAt: string | null | undefined,
): Date | null {
  if ((priority ?? TaskPriority.NONE) !== TaskPriority.REMINDER) {
    return null;
  }
  if (!remindAt) {
    throw new BadRequestException('提醒要选一个时间');
  }
  return parseReminderInstant(remindAt, new Date());
}

function applyReminder(
  task: { priority: string; remindAt: Date | null },
  dto: UpdateTaskDto,
  data: Prisma.TaskUpdateInput,
): void {
  const current = task.priority as TaskPriority;
  const nextPriority = dto.priority ?? current;
  if (nextPriority !== TaskPriority.REMINDER) {
    if (dto.priority !== undefined || dto.remindAt === null) {
      data.remindAt = null;
      data.remindedAt = null;
    }
    return;
  }
  if (typeof dto.remindAt === 'string') {
    data.remindAt = parseReminderInstant(dto.remindAt, new Date());
    data.remindedAt = null;
    return;
  }
  const turningOn =
    dto.priority === TaskPriority.REMINDER &&
    current !== TaskPriority.REMINDER;
  if (dto.remindAt === null || task.remindAt == null || turningOn) {
    throw new BadRequestException('提醒要选一个时间');
  }
}
