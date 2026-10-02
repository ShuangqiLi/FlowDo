import { Injectable, NotFoundException } from '@nestjs/common';
import { Space } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { INSTANCE_ID } from './constants';

@Injectable()
export class InstanceService {
  constructor(private readonly prisma: PrismaService) {}

  async spaceId(): Promise<string> {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
      select: { activeSpaceId: true },
    });
    if (!instance?.activeSpaceId) {
      throw new NotFoundException('还没有任务空间');
    }
    return instance.activeSpaceId;
  }

  /** 当前任务空间的主题、聚焦上限和归档习惯。 */
  async activeSpace(): Promise<Space> {
    const spaceId = await this.spaceId();
    const space = await this.prisma.space.findUnique({ where: { id: spaceId } });
    if (!space) {
      throw new NotFoundException('这个任务空间找不到了');
    }
    return space;
  }
}
