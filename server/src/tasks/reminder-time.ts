import { BadRequestException } from '@nestjs/common';
import { nextCronOccurrence } from '../clock/cron';
import {
  stepLunarMonth,
  stepLunarYear,
  type SolarDate,
} from '../clock/lunar';
import { DEFAULT_TZ_OFFSET_MINUTES } from '../clock/zone';
import { RemindRepeat } from './task.enums';

const repeats = new Set<string>(Object.values(RemindRepeat));

export type ReminderStepOptions = {
  cron?: string | null;
  lunar?: boolean;
  tzOffsetMinutes?: number;
};

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

export function asRemindRepeat(raw: string | undefined): RemindRepeat {
  if (raw == null || raw === '') {
    return RemindRepeat.ONCE;
  }
  if (!repeats.has(raw)) {
    throw new BadRequestException('这种重复方式还不认识');
  }
  return raw as RemindRepeat;
}

function wallParts(instant: Date, offsetMinutes: number) {
  const shifted = new Date(instant.getTime() + offsetMinutes * 60_000);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
    hour: shifted.getUTCHours(),
    minute: shifted.getUTCMinutes(),
  };
}

function fromWall(
  solar: SolarDate,
  hour: number,
  minute: number,
  offsetMinutes: number,
): Date {
  return new Date(
    Date.UTC(solar.year, solar.month - 1, solar.day, hour, minute, 0, 0) -
      offsetMinutes * 60_000,
  );
}

function stepLunar(
  from: Date,
  repeat: RemindRepeat,
  offsetMinutes: number,
): Date {
  const wall = wallParts(from, offsetMinutes);
  const solar = { year: wall.year, month: wall.month, day: wall.day };
  const next =
    repeat === RemindRepeat.YEARLY ? stepLunarYear(solar) : stepLunarMonth(solar);
  if (next == null) {
    throw new BadRequestException('这个农历日期走不到下一次');
  }
  return fromWall(next, wall.hour, wall.minute, offsetMinutes);
}

/** 下一次固定时刻。月底、闰日不够时落到当月最后一天。 */
export function stepReminder(
  from: Date,
  repeat: RemindRepeat,
  options: ReminderStepOptions = {},
): Date {
  const offset = options.tzOffsetMinutes ?? DEFAULT_TZ_OFFSET_MINUTES;
  if (repeat === RemindRepeat.CRON) {
    if (!options.cron) {
      throw new BadRequestException('crontab 要写完整');
    }
    return nextCronOccurrence(options.cron, from, offset);
  }
  if (
    options.lunar &&
    (repeat === RemindRepeat.MONTHLY || repeat === RemindRepeat.YEARLY)
  ) {
    return stepLunar(from, repeat, offset);
  }
  const next = new Date(from);
  const day = next.getDate();
  const month = next.getMonth();
  switch (repeat) {
    case RemindRepeat.DAILY:
      next.setDate(day + 1);
      break;
    case RemindRepeat.WEEKLY:
      next.setDate(day + 7);
      break;
    case RemindRepeat.MONTHLY:
      next.setDate(1);
      next.setMonth(month + 1);
      next.setDate(Math.min(day, daysInMonth(next.getFullYear(), next.getMonth())));
      break;
    case RemindRepeat.YEARLY:
      next.setDate(1);
      next.setFullYear(next.getFullYear() + 1);
      next.setMonth(month);
      next.setDate(Math.min(day, daysInMonth(next.getFullYear(), month)));
      break;
    default:
      break;
  }
  next.setSeconds(0, 0);
  return next;
}

/** 至少向前走一次，并且走到严格晚于现在。 */
export function advanceReminder(
  from: Date,
  repeat: RemindRepeat,
  now: Date,
  options: ReminderStepOptions = {},
): Date {
  let cursor = new Date(from);
  for (let i = 0; i < 4000; i++) {
    cursor = stepReminder(cursor, repeat, options);
    if (cursor.getTime() > now.getTime()) {
      return cursor;
    }
  }
  return cursor;
}

/** 这个月里还会响的时刻，不含已经过去的。 */
export function reminderMarks(
  nextAt: Date,
  repeat: RemindRepeat,
  monthStart: Date,
  monthEnd: Date,
  now: Date,
  options: ReminderStepOptions = {},
): Date[] {
  const marks: Date[] = [];
  let cursor = new Date(nextAt);
  for (let i = 0; i < 400 && cursor.getTime() <= monthEnd.getTime(); i++) {
    if (cursor.getTime() > now.getTime() && cursor.getTime() >= monthStart.getTime()) {
      marks.push(new Date(cursor));
    }
    if (repeat === RemindRepeat.ONCE) {
      break;
    }
    const stepped = stepReminder(cursor, repeat, options);
    if (stepped.getTime() <= cursor.getTime()) {
      break;
    }
    cursor = stepped;
  }
  return marks;
}

function daysInMonth(year: number, monthIndex: number): number {
  return new Date(year, monthIndex + 1, 0).getDate();
}
