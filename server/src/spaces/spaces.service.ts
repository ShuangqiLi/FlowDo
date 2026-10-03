import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { INSTANCE_ID } from '../instance/constants';
import { PrismaService } from '../prisma/prisma.service';
import { SpaceNameDto } from './dto/space.dto';

@Injectable()
export class SpacesService {
  constructor(private readonly prisma: PrismaService) {}

  list() {
    return this.prisma.space.findMany({ orderBy: { createdAt: 'asc' } });
  }

  async create(dto: SpaceNameDto) {
    return this.prisma.space.create({ data: { name: dto.name.trim() } });
  }

  async rename(id: string, dto: SpaceNameDto) {
    const space = await this.prisma.space.findUnique({ where: { id } });
    if (!space) {
      throw new NotFoundException('这个任务空间找不到了');
    }
    return this.prisma.space.update({
      where: { id },
      data: { name: dto.name.trim() },
    });
  }

  async taskCount(id: string) {
    const space = await this.prisma.space.findUnique({ where: { id } });
    if (!space) {
      throw new NotFoundException('这个任务空间找不到了');
    }
    const count = await this.prisma.task.count({ where: { spaceId: id } });
    return { count };
  }

  async remove(id: string) {
    const spaces = await this.prisma.space.findMany({
      orderBy: { createdAt: 'asc' },
    });
    const target = spaces.find((space) => space.id === id);
    if (!target) {
      throw new NotFoundException('这个任务空间找不到了');
    }
    if (spaces.length <= 1) {
      throw new BadRequestException('至少留一个任务空间');
    }
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
    });
    if (instance?.activeSpaceId === id) {
      const next = spaces.find((space) => space.id !== id);
      await this.prisma.instance.update({
        where: { id: INSTANCE_ID },
        data: { activeSpaceId: next?.id },
      });
    }
    await this.prisma.space.delete({ where: { id } });
    return { ok: true };
  }
}
