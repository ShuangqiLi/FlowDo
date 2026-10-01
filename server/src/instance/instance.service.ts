import { Injectable, NotFoundException } from '@nestjs/common';
import { Instance } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { INSTANCE_ID } from './constants';

@Injectable()
export class InstanceService {
  constructor(private readonly prisma: PrismaService) {}

  async get(): Promise<Instance> {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
    });
    if (!instance) {
      throw new NotFoundException('这台 FlowDo 还没准备好');
    }
    return instance;
  }

  async spaceId(): Promise<string> {
    const instance = await this.get();
    if (!instance.activeSpaceId) {
      throw new NotFoundException('还没有任务空间');
    }
    return instance.activeSpaceId;
  }
}
