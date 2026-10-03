import { BadRequestException } from '@nestjs/common';

export type CronFields = {
  minute: boolean[];
  hour: boolean[];
  day: boolean[];
  month: boolean[];
  weekday: boolean[];
};

const RANGES = [
  { min: 0, max: 59, name: '分' },
  { min: 0, max: 23, name: '时' },
  { min: 1, max: 31, name: '日' },
  { min: 1, max: 12, name: '月' },
  { min: 0, max: 7, name: '周' },
] as const;

function parsePart(
  part: string,
  min: number,
  max: number,
  name: string,
): boolean[] {
  const allowed = Array.from({ length: max + 1 }, () => false);
  if (part === '*' || part === '?') {
    for (let i = min; i <= max; i++) {
      allowed[i] = true;
    }
    return allowed;
  }
  for (const item of part.split(',')) {
    if (item === '') {
      throw new BadRequestException(`crontab 的${name}不太对`);
    }
    const [rangeRaw, stepRaw] = item.split('/');
    const step = stepRaw == null ? 1 : Number(stepRaw);
    if (!Number.isInteger(step) || step < 1) {
      throw new BadRequestException(`crontab 的${name}不太对`);
    }
    let start: number;
    let end: number;
    if (rangeRaw === '*') {
      start = min;
      end = max;
    } else if (rangeRaw.includes('-')) {
      const bits = rangeRaw.split('-');
      if (bits.length !== 2) {
        throw new BadRequestException(`crontab 的${name}不太对`);
      }
      start = Number(bits[0]);
      end = Number(bits[1]);
    } else {
      start = Number(rangeRaw);
      end = start;
    }
    if (
      !Number.isInteger(start) ||
      !Number.isInteger(end) ||
      start < min ||
      end > max ||
      start > end
    ) {
      throw new BadRequestException(`crontab 的${name}不太对`);
    }
    for (let value = start; value <= end; value += step) {
      allowed[value] = true;
    }
  }
  return allowed;
}

function allSet(flags: boolean[], min: number, max: number): boolean {
  for (let i = min; i <= max; i++) {
    if (!flags[i]) {
      return false;
    }
  }
  return true;
}

export function parseCron(raw: string): CronFields {
  const parts = raw.trim().split(/\s+/);
  if (parts.length !== 5) {
    throw new BadRequestException('crontab 用五段：分 时 日 月 周');
  }
  return {
    minute: parsePart(parts[0], RANGES[0].min, RANGES[0].max, RANGES[0].name),
    hour: parsePart(parts[1], RANGES[1].min, RANGES[1].max, RANGES[1].name),
    day: parsePart(parts[2], RANGES[2].min, RANGES[2].max, RANGES[2].name),
    month: parsePart(parts[3], RANGES[3].min, RANGES[3].max, RANGES[3].name),
    weekday: parsePart(parts[4], RANGES[4].min, RANGES[4].max, RANGES[4].name),
  };
}

export function normalizeCron(raw: string | null | undefined): string {
  if (raw == null || raw.trim() === '') {
    throw new BadRequestException('crontab 要写完整');
  }
  const trimmed = raw.trim().split(/\s+/).join(' ');
  parseCron(trimmed);
  if (trimmed.length > 80) {
    throw new BadRequestException('crontab 太长啦');
  }
  return trimmed;
}

export function cronMatches(
  fields: CronFields,
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
): boolean {
  if (!fields.minute[minute] || !fields.hour[hour] || !fields.month[month]) {
    return false;
  }
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  const weekdayHit = fields.weekday[weekday] || (weekday === 0 && fields.weekday[7]);
  const dayAny = allSet(fields.day, 1, 31);
  const weekdayAny = allSet(fields.weekday, 0, 7);
  if (dayAny && weekdayAny) {
    return true;
  }
  if (!dayAny && weekdayAny) {
    return fields.day[day] === true;
  }
  if (dayAny && !weekdayAny) {
    return weekdayHit;
  }
  return fields.day[day] === true || weekdayHit;
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
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  offsetMinutes: number,
): Date {
  return new Date(
    Date.UTC(year, month - 1, day, hour, minute, 0, 0) - offsetMinutes * 60_000,
  );
}

/** 严格晚于 from 的下一次。按客户端时区的墙钟解释 crontab。 */
export function nextCronOccurrence(
  expr: string,
  from: Date,
  offsetMinutes: number,
): Date {
  const fields = parseCron(expr);
  const start = new Date(from);
  start.setSeconds(0, 0);
  let cursor = start.getTime() + 60_000;
  const limit = cursor + 4 * 366 * 24 * 60 * 60_000;
  while (cursor <= limit) {
    const wall = wallParts(new Date(cursor), offsetMinutes);
    if (
      cronMatches(
        fields,
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      )
    ) {
      return fromWall(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
        offsetMinutes,
      );
    }
    cursor += 60_000;
  }
  throw new BadRequestException('crontab 找不到下一次');
}
