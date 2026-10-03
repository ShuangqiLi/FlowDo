import { BadRequestException } from '@nestjs/common';

/** 没带时区时按中国用。分钟，东边为正。 */
export const DEFAULT_TZ_OFFSET_MINUTES = 8 * 60;

const MIN_OFFSET = -14 * 60;
const MAX_OFFSET = 14 * 60;

export function parseTzOffset(raw: string | undefined): number {
  if (raw == null || raw === '') {
    return DEFAULT_TZ_OFFSET_MINUTES;
  }
  const n = Number(raw);
  if (!Number.isInteger(n) || n < MIN_OFFSET || n > MAX_OFFSET) {
    throw new BadRequestException('时区不太对');
  }
  return n;
}

/** 按客户端时区算出年月日，避免 Docker 用 UTC 时把早上的事算到前一天。 */
export function toDateKey(date: Date, offsetMinutes: number): string {
  const shifted = new Date(date.getTime() + offsetMinutes * 60_000);
  const y = shifted.getUTCFullYear();
  const m = `${shifted.getUTCMonth() + 1}`.padStart(2, '0');
  const d = `${shifted.getUTCDate()}`.padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function zonedInstant(
  year: number,
  monthIndex: number,
  day: number,
  hour: number,
  minute: number,
  offsetMinutes: number,
): Date {
  return new Date(
    Date.UTC(year, monthIndex, day, hour, minute, 0, 0) -
      offsetMinutes * 60_000,
  );
}

export function startOfZonedDay(date: Date, offsetMinutes: number): Date {
  const key = toDateKey(date, offsetMinutes);
  const [year, month, day] = key.split('-').map(Number);
  return zonedInstant(year, month - 1, day, 0, 0, offsetMinutes);
}

export function monthRange(
  year: number,
  month: number,
  offsetMinutes: number,
): { start: Date; end: Date } {
  const start = zonedInstant(year, month - 1, 1, 0, 0, offsetMinutes);
  const end = new Date(
    zonedInstant(year, month, 1, 0, 0, offsetMinutes).getTime() - 1,
  );
  return { start, end };
}

export function monthDateKey(year: number, month: number, day: number): string {
  return `${year}-${`${month}`.padStart(2, '0')}-${`${day}`.padStart(2, '0')}`;
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}
