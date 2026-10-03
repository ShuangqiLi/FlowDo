import { BadRequestException } from '@nestjs/common';

/** 提醒精确到分钟，而且必须晚于现在。 */
export function parseReminderInstant(raw: string, now: Date): Date {
  const at = new Date(raw);
  if (Number.isNaN(at.getTime())) {
    throw new BadRequestException('提醒时间不太对');
  }
  const minute = new Date(at);
  minute.setSeconds(0, 0);
  if (minute.getTime() <= now.getTime()) {
    throw new BadRequestException('提醒时间要比现在晚');
  }
  return minute;
}
