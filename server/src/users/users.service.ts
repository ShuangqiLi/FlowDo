import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { INSTANCE_ID } from '../instance/constants';
import { UpdateMeDto } from './dto/update-me.dto';

const meSelect = {
  id: true,
  mustChangePassword: true,
  activeSpaceId: true,
  archiveAfterDays: true,
  focusLimit: true,
  deleteArchivedAfterDays: true,
  showArchiveTab: true,
  themeKey: true,
  voiceInputEnabled: true,
  createdAt: true,
} as const;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe() {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
      select: meSelect,
    });
    if (!instance) {
      throw new NotFoundException('这台 FlowDo 还没准备好');
    }
    return instance;
  }

  async updateMe(dto: UpdateMeDto) {
    if (dto.activeSpaceId) {
      const space = await this.prisma.space.findUnique({
        where: { id: dto.activeSpaceId },
      });
      if (!space) {
        throw new BadRequestException('这个任务空间找不到了');
      }
    }
    return this.prisma.instance.update({
      where: { id: INSTANCE_ID },
      data: {
        ...(dto.archiveAfterDays !== undefined
          ? { archiveAfterDays: dto.archiveAfterDays }
          : {}),
        ...(dto.focusLimit !== undefined ? { focusLimit: dto.focusLimit } : {}),
        ...(dto.deleteArchivedAfterDays !== undefined
          ? { deleteArchivedAfterDays: dto.deleteArchivedAfterDays }
          : {}),
        ...(dto.showArchiveTab !== undefined
          ? { showArchiveTab: dto.showArchiveTab }
          : {}),
        ...(dto.themeKey !== undefined ? { themeKey: dto.themeKey } : {}),
        ...(dto.voiceInputEnabled !== undefined
          ? { voiceInputEnabled: dto.voiceInputEnabled }
          : {}),
        ...(dto.activeSpaceId !== undefined
          ? { activeSpaceId: dto.activeSpaceId }
          : {}),
      },
      select: meSelect,
    });
  }
}
