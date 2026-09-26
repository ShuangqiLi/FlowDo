import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateMeDto } from './dto/update-me.dto';

const meSelect = {
  id: true,
  username: true,
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

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: meSelect,
    });
    if (!user) {
      throw new NotFoundException('账号找不到了');
    }
    return user;
  }

  async updateMe(userId: string, dto: UpdateMeDto) {
    return this.prisma.user.update({
      where: { id: userId },
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
      },
      select: meSelect,
    });
  }
}
