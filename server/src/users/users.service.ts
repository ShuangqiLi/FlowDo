import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { INSTANCE_ID } from '../instance/constants';
import { UpdateMeDto } from './dto/update-me.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe() {
    return this.presentMe();
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

    const instancePatch = {
      ...(dto.voiceInputEnabled !== undefined
        ? { voiceInputEnabled: dto.voiceInputEnabled }
        : {}),
      ...(dto.activeSpaceId !== undefined
        ? { activeSpaceId: dto.activeSpaceId }
        : {}),
    };
    if (Object.keys(instancePatch).length > 0) {
      await this.prisma.instance.update({
        where: { id: INSTANCE_ID },
        data: instancePatch,
      });
    }

    const spacePatch = {
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
    };
    if (Object.keys(spacePatch).length > 0) {
      const instance = await this.prisma.instance.findUnique({
        where: { id: INSTANCE_ID },
        select: { activeSpaceId: true },
      });
      if (!instance?.activeSpaceId) {
        throw new NotFoundException('还没有任务空间');
      }
      await this.prisma.space.update({
        where: { id: instance.activeSpaceId },
        data: spacePatch,
      });
    }

    return this.presentMe();
  }

  private async presentMe() {
    const instance = await this.prisma.instance.findUnique({
      where: { id: INSTANCE_ID },
      include: { activeSpace: true },
    });
    if (!instance) {
      throw new NotFoundException('这台 FlowDo 还没准备好');
    }
    const space = instance.activeSpace;
    if (!space) {
      throw new NotFoundException('还没有任务空间');
    }
    return {
      id: instance.id,
      mustChangePassword: instance.mustChangePassword,
      activeSpaceId: instance.activeSpaceId,
      voiceInputEnabled: instance.voiceInputEnabled,
      archiveAfterDays: space.archiveAfterDays,
      focusLimit: space.focusLimit,
      deleteArchivedAfterDays: space.deleteArchivedAfterDays,
      showArchiveTab: space.showArchiveTab,
      themeKey: space.themeKey,
      createdAt: instance.createdAt,
    };
  }
}
