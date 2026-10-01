import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Reminder, ReminderCalendar, ReminderKind, ReminderRecurrence } from '@prisma/client';
import { InstanceService } from '../instance/instance.service';
import { PrismaService } from '../prisma/prisma.service';
import { ReminderDto } from './dto/reminder.dto';
import {
  formatLunarDate,
  initialNextDate,
  nextOccurrence,
  startOfDay,
  toDateKey,
  type ReminderRule,
} from './lunar-date';

@Injectable()
export class RemindersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly instance: InstanceService,
  ) {}

  async list() {
    const spaceId = await this.instance.spaceId();
    const rows = await this.prisma.reminder.findMany({
      where: { spaceId },
      orderBy: { nextDate: 'asc' },
    });
    return rows.map(presentReminder);
  }

  async create(dto: ReminderDto) {
    const spaceId = await this.instance.spaceId();
    const data = this.toData(dto);
    const row = await this.prisma.reminder.create({
      data: { spaceId, ...data },
    });
    return presentReminder(row);
  }

  async update(id: string, dto: ReminderDto) {
    const spaceId = await this.instance.spaceId();
    const existing = await this.prisma.reminder.findFirst({
      where: { id, spaceId },
    });
    if (!existing) {
      throw new NotFoundException('这条提醒找不到了');
    }
    const row = await this.prisma.reminder.update({
      where: { id },
      data: this.toData(dto),
    });
    return presentReminder(row);
  }

  async remove(id: string) {
    const spaceId = await this.instance.spaceId();
    const existing = await this.prisma.reminder.findFirst({
      where: { id, spaceId },
    });
    if (!existing) {
      throw new NotFoundException('这条提醒找不到了');
    }
    await this.prisma.reminder.delete({ where: { id } });
    return { ok: true };
  }

  /** 今天这条知道了：一次的删掉，循环的推到下一次。 */
  async acknowledge(id: string) {
    const spaceId = await this.instance.spaceId();
    const existing = await this.prisma.reminder.findFirst({
      where: { id, spaceId },
    });
    if (!existing) {
      throw new NotFoundException('这条提醒找不到了');
    }
    if (existing.recurrence === ReminderRecurrence.NONE) {
      await this.prisma.reminder.delete({ where: { id } });
      return { ok: true, reminder: null };
    }
    const tomorrow = startOfDay(new Date());
    tomorrow.setDate(tomorrow.getDate() + 1);
    const next = nextOccurrence(toRule(existing), tomorrow);
    const row = await this.prisma.reminder.update({
      where: { id },
      data: { nextDate: next },
    });
    return { ok: true, reminder: presentReminder(row) };
  }

  private toData(dto: ReminderDto) {
    const recurrence =
      dto.kind === ReminderKind.ANNIVERSARY &&
      dto.recurrence === ReminderRecurrence.NONE
        ? ReminderRecurrence.YEARLY
        : dto.recurrence;
    if (dto.calendar === ReminderCalendar.LUNAR) {
      if (!dto.lunarMonth || !dto.lunarDay) {
        throw new BadRequestException('农历要选月和日');
      }
      if (
        recurrence === ReminderRecurrence.DAILY ||
        recurrence === ReminderRecurrence.WEEKLY
      ) {
        throw new BadRequestException('农历提醒请选一次、每月或每年');
      }
    } else if (!dto.date) {
      throw new BadRequestException('选个公历日期');
    }

    let nextDate: Date;
    try {
      nextDate = initialNextDate({
        calendar: dto.calendar,
        recurrence,
        date: dto.date,
        lunarMonth: dto.lunarMonth,
        lunarDay: dto.lunarDay,
        leapMonth: dto.leapMonth ?? false,
      });
    } catch (error) {
      throw new BadRequestException(
        error instanceof Error ? error.message : '这个日期不太对',
      );
    }

    return {
      title: dto.title.trim(),
      note: dto.note?.trim() ? dto.note.trim() : null,
      calendar: dto.calendar,
      recurrence,
      kind: dto.kind ?? ReminderKind.NORMAL,
      nextDate,
      lunarMonth: dto.calendar === ReminderCalendar.LUNAR ? dto.lunarMonth : null,
      lunarDay: dto.calendar === ReminderCalendar.LUNAR ? dto.lunarDay : null,
      leapMonth: dto.calendar === ReminderCalendar.LUNAR ? (dto.leapMonth ?? false) : false,
    };
  }
}

export function toRule(row: Reminder): ReminderRule {
  return {
    calendar: row.calendar,
    recurrence: row.recurrence,
    nextDate: row.nextDate,
    lunarMonth: row.lunarMonth,
    lunarDay: row.lunarDay,
    leapMonth: row.leapMonth,
  };
}

export function presentReminder(row: Reminder) {
  return {
    id: row.id,
    title: row.title,
    note: row.note,
    calendar: row.calendar,
    recurrence: row.recurrence,
    kind: row.kind,
    nextDate: toDateKey(row.nextDate),
    lunarMonth: row.lunarMonth,
    lunarDay: row.lunarDay,
    leapMonth: row.leapMonth,
    lunarText:
      row.calendar === ReminderCalendar.LUNAR && row.lunarMonth && row.lunarDay
        ? formatLunarDate(row.lunarMonth, row.lunarDay, row.leapMonth)
        : null,
  };
}
