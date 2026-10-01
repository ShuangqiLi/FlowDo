import { Lunar, LunarYear, Solar } from 'lunar-javascript';

export type CalendarKind = 'SOLAR' | 'LUNAR';
export type RecurrenceKind = 'NONE' | 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';

export type ReminderRule = {
  calendar: CalendarKind;
  recurrence: RecurrenceKind;
  nextDate: Date;
  lunarMonth: number | null;
  lunarDay: number | null;
  leapMonth: boolean;
};

const MONTH_NAMES = ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'];

export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

export function addDays(date: Date, days: number): Date {
  const next = startOfDay(date);
  next.setDate(next.getDate() + days);
  return next;
}

export function toDateKey(date: Date): string {
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, '0');
  const d = `${date.getDate()}`.padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function parseDateKey(key: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key);
  if (!match) {
    throw new Error('日期要写成 YYYY-MM-DD');
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day);
  if (
    date.getFullYear() !== year ||
    date.getMonth() !== month - 1 ||
    date.getDate() !== day
  ) {
    throw new Error('这个日期不存在');
  }
  return date;
}

export function lunarDayLabel(date: Date): string {
  const solar = Solar.fromYmd(
    date.getFullYear(),
    date.getMonth() + 1,
    date.getDate(),
  );
  const lunar = solar.getLunar();
  if (lunar.getDay() === 1) {
    return `${lunar.getMonthInChinese()}月`;
  }
  return lunar.getDayInChinese();
}

export function formatLunarDate(
  month: number,
  day: number,
  leap: boolean,
): string {
  const monthName = MONTH_NAMES[month - 1] ?? `${month}`;
  const sample = Lunar.fromYmd(2020, 2, Math.min(Math.max(day, 1), 30));
  return `${leap ? '闰' : ''}${monthName}月${sample.getDayInChinese()}`;
}

function lunarMonths(year: number) {
  return LunarYear.fromYear(year)
    .getMonths()
    .filter((month) => month.getYear() === year);
}

/** 指定年里这个农历月的月序号（闰月为负）。没有闰月时退回平月。 */
function resolveMonthIndex(
  year: number,
  month: number,
  leap: boolean,
): number | null {
  const months = lunarMonths(year);
  if (leap) {
    const leapMonth = months.find((item) => item.getMonth() === -month);
    if (leapMonth) {
      return leapMonth.getMonth();
    }
  }
  const plain = months.find((item) => item.getMonth() === month);
  return plain ? plain.getMonth() : null;
}

export function lunarToSolar(
  year: number,
  month: number,
  day: number,
  leap: boolean,
): Date | null {
  const index = resolveMonthIndex(year, month, leap);
  if (index == null) {
    return null;
  }
  const info = lunarMonths(year).find((item) => item.getMonth() === index);
  const useDay = Math.min(day, info?.getDayCount() ?? day);
  const lunar = Lunar.fromYmd(year, index, useDay);
  const solar = lunar.getSolar();
  return startOfDay(new Date(solar.getYear(), solar.getMonth() - 1, solar.getDay()));
}

function solarClamp(year: number, month: number, day: number): Date {
  const last = new Date(year, month, 0).getDate();
  return startOfDay(new Date(year, month - 1, Math.min(day, last)));
}

function nextSolarMonthly(monthDay: number, from: Date): Date {
  const start = startOfDay(from);
  for (let offset = 0; offset < 24; offset += 1) {
    const cursor = new Date(start.getFullYear(), start.getMonth() + offset, 1);
    const candidate = solarClamp(
      cursor.getFullYear(),
      cursor.getMonth() + 1,
      monthDay,
    );
    if (candidate.getTime() >= start.getTime()) {
      return candidate;
    }
  }
  return solarClamp(start.getFullYear() + 2, start.getMonth() + 1, monthDay);
}

function nextSolarYearly(month: number, day: number, from: Date): Date {
  const start = startOfDay(from);
  for (let year = start.getFullYear(); year < start.getFullYear() + 8; year += 1) {
    const candidate = solarClamp(year, month, day);
    if (candidate.getTime() >= start.getTime()) {
      return candidate;
    }
  }
  return solarClamp(start.getFullYear() + 8, month, day);
}

function nextLunarYearly(
  month: number,
  day: number,
  leap: boolean,
  from: Date,
): Date {
  const start = startOfDay(from);
  for (let year = start.getFullYear() - 1; year < start.getFullYear() + 4; year += 1) {
    const solar = lunarToSolar(year, month, day, leap);
    if (solar && solar.getTime() >= start.getTime()) {
      return solar;
    }
  }
  throw new Error('找不到下一次农历日期');
}

function nextLunarMonthly(day: number, from: Date): Date {
  const start = startOfDay(from);
  for (let year = start.getFullYear() - 1; year < start.getFullYear() + 3; year += 1) {
    for (const month of lunarMonths(year)) {
      if (month.getMonth() < 0) {
        continue;
      }
      const useDay = Math.min(day, month.getDayCount());
      const lunar = Lunar.fromYmd(year, month.getMonth(), useDay);
      const solarDate = lunar.getSolar();
      const solar = startOfDay(
        new Date(solarDate.getYear(), solarDate.getMonth() - 1, solarDate.getDay()),
      );
      if (solar.getTime() >= start.getTime()) {
        return solar;
      }
    }
  }
  throw new Error('找不到下一次农历日期');
}

function nextWeekly(weekday: number, from: Date): Date {
  const start = startOfDay(from);
  const delta = (weekday - start.getDay() + 7) % 7;
  return addDays(start, delta);
}

/** 下一次不早于 from 的公历日。 */
export function nextOccurrence(rule: ReminderRule, from: Date): Date {
  const start = startOfDay(from);
  if (rule.recurrence === 'NONE' || rule.recurrence === 'DAILY') {
    const anchored = startOfDay(rule.nextDate);
    return anchored.getTime() >= start.getTime() ? anchored : start;
  }
  if (rule.recurrence === 'WEEKLY') {
    return nextWeekly(startOfDay(rule.nextDate).getDay(), start);
  }
  if (rule.calendar === 'LUNAR') {
    const month = rule.lunarMonth ?? 1;
    const day = rule.lunarDay ?? 1;
    if (rule.recurrence === 'YEARLY') {
      return nextLunarYearly(month, day, rule.leapMonth, start);
    }
    return nextLunarMonthly(day, start);
  }
  const anchor = startOfDay(rule.nextDate);
  if (rule.recurrence === 'YEARLY') {
    return nextSolarYearly(anchor.getMonth() + 1, anchor.getDate(), start);
  }
  return nextSolarMonthly(anchor.getDate(), start);
}

export function initialNextDate(
  input: {
    calendar: CalendarKind;
    recurrence: RecurrenceKind;
    date?: string;
    lunarMonth?: number;
    lunarDay?: number;
    leapMonth?: boolean;
  },
  today = new Date(),
): Date {
  if (input.calendar === 'LUNAR') {
    const month = input.lunarMonth ?? 1;
    const day = input.lunarDay ?? 1;
    const leap = input.leapMonth ?? false;
    const rule: ReminderRule = {
      calendar: 'LUNAR',
      recurrence: input.recurrence === 'NONE' ? 'YEARLY' : input.recurrence,
      nextDate: startOfDay(today),
      lunarMonth: month,
      lunarDay: day,
      leapMonth: leap,
    };
    if (input.recurrence === 'DAILY') {
      return startOfDay(today);
    }
    if (input.recurrence === 'WEEKLY') {
      return startOfDay(today);
    }
    return nextOccurrence(rule, today);
  }
  if (!input.date) {
    throw new Error('选个公历日期');
  }
  const date = parseDateKey(input.date);
  if (input.recurrence === 'NONE' || input.recurrence === 'DAILY' || input.recurrence === 'WEEKLY') {
    return date;
  }
  const rule: ReminderRule = {
    calendar: 'SOLAR',
    recurrence: input.recurrence,
    nextDate: date,
    lunarMonth: null,
    lunarDay: null,
    leapMonth: false,
  };
  return nextOccurrence(rule, date.getTime() >= startOfDay(today).getTime() ? date : today);
}

/** 日历上这个公历月会落到哪些天。 */
export function occurrenceKeysInMonth(
  rule: ReminderRule,
  year: number,
  month: number,
): string[] {
  const days = new Date(year, month, 0).getDate();
  const keys: string[] = [];
  if (rule.recurrence === 'NONE') {
    const key = toDateKey(startOfDay(rule.nextDate));
    const [y, m] = key.split('-').map(Number);
    if (y === year && m === month) {
      keys.push(key);
    }
    return keys;
  }
  for (let day = 1; day <= days; day += 1) {
    const date = new Date(year, month - 1, day);
    if (occursOn(rule, date)) {
      keys.push(toDateKey(date));
    }
  }
  return keys;
}

function occursOn(rule: ReminderRule, date: Date): boolean {
  const day = startOfDay(date);
  if (rule.recurrence === 'DAILY') {
    return true;
  }
  if (rule.recurrence === 'WEEKLY') {
    return day.getDay() === startOfDay(rule.nextDate).getDay();
  }
  if (rule.calendar === 'LUNAR' && rule.lunarMonth && rule.lunarDay) {
    const solar = Solar.fromYmd(day.getFullYear(), day.getMonth() + 1, day.getDate());
    const lunar = solar.getLunar();
    const length = daysInLunarMonth(lunar.getYear(), lunar.getMonth());
    if (lunar.getDay() !== Math.min(rule.lunarDay, length)) {
      return false;
    }
    if (rule.recurrence === 'YEARLY') {
      const month = lunar.getMonth();
      if (rule.leapMonth && yearHasLeap(lunar.getYear(), rule.lunarMonth)) {
        return month === -rule.lunarMonth;
      }
      return month === rule.lunarMonth;
    }
    return lunar.getMonth() > 0;
  }
  const anchor = startOfDay(rule.nextDate);
  if (rule.recurrence === 'YEARLY') {
    const clamped = solarClamp(day.getFullYear(), anchor.getMonth() + 1, anchor.getDate());
    return toDateKey(clamped) === toDateKey(day);
  }
  const clamped = solarClamp(day.getFullYear(), day.getMonth() + 1, anchor.getDate());
  return toDateKey(clamped) === toDateKey(day);
}

function daysInLunarMonth(year: number, monthIndex: number): number {
  const info = lunarMonths(year).find((item) => item.getMonth() === monthIndex);
  return info?.getDayCount() ?? 30;
}

function yearHasLeap(year: number, month: number): boolean {
  return lunarMonths(year).some((item) => item.getMonth() === -month);
}
