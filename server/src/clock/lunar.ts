/** 农历 1900–2100。编码与常见 calendar.js 一致。 */

const LUNAR_INFO = [
  0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2, // 1900
  0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
  0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
  0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
  0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
  0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5d0, 0x14573, 0x052d0, 0x0a9a8, 0x0e950, 0x06aa0,
  0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
  0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b5a0, 0x195a6,
  0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
  0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
  0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
  0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
  0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
  0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
  0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
  0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0, // 2050
  0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
  0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
  0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
  0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
  0x0d520,
];

const MONTH_NAMES = [
  '正',
  '二',
  '三',
  '四',
  '五',
  '六',
  '七',
  '八',
  '九',
  '十',
  '冬',
  '腊',
];

const DAY_NAMES = [
  '',
  '初一',
  '初二',
  '初三',
  '初四',
  '初五',
  '初六',
  '初七',
  '初八',
  '初九',
  '初十',
  '十一',
  '十二',
  '十三',
  '十四',
  '十五',
  '十六',
  '十七',
  '十八',
  '十九',
  '二十',
  '廿一',
  '廿二',
  '廿三',
  '廿四',
  '廿五',
  '廿六',
  '廿七',
  '廿八',
  '廿九',
  '三十',
];

export type LunarDate = {
  year: number;
  month: number;
  day: number;
  leap: boolean;
};

export type SolarDate = {
  year: number;
  month: number;
  day: number;
};

const MIN_YEAR = 1900;
const MAX_YEAR = 2100;

function info(year: number): number {
  return LUNAR_INFO[year - MIN_YEAR] ?? 0;
}

export function leapMonth(year: number): number {
  return info(year) & 0xf;
}

export function leapDays(year: number): number {
  if (leapMonth(year) === 0) {
    return 0;
  }
  return info(year) & 0x10000 ? 30 : 29;
}

export function lunarMonthDays(year: number, month: number): number {
  if (month < 1 || month > 12) {
    return 0;
  }
  return info(year) & (0x10000 >> month) ? 30 : 29;
}

export function lunarYearDays(year: number): number {
  let sum = 348;
  for (let bit = 0x8000; bit > 0x8; bit >>= 1) {
    sum += info(year) & bit ? 1 : 0;
  }
  return sum + leapDays(year);
}

export function lunarMonthLength(
  year: number,
  month: number,
  leap: boolean,
): number {
  if (leap) {
    return leapMonth(year) === month ? leapDays(year) : 0;
  }
  return lunarMonthDays(year, month);
}

function inRange(year: number): boolean {
  return year >= MIN_YEAR && year <= MAX_YEAR;
}

/** 公历年月日 → 农历。超出表范围时返回 null。 */
export function solarToLunar(
  year: number,
  month: number,
  day: number,
): LunarDate | null {
  if (!inRange(year) || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  const offset =
    (Date.UTC(year, month - 1, day) - Date.UTC(1900, 0, 31)) / 86_400_000;
  if (offset < 0) {
    return null;
  }
  let remain = offset;
  let y = 1900;
  let temp = 0;
  for (; y < 2101 && remain > 0; y++) {
    temp = lunarYearDays(y);
    remain -= temp;
  }
  if (remain < 0) {
    remain += temp;
    y -= 1;
  }
  const leap = leapMonth(y);
  let isLeap = false;
  let m = 1;
  for (; m < 13 && remain > 0; m++) {
    if (leap > 0 && m === leap + 1 && !isLeap) {
      m -= 1;
      isLeap = true;
      temp = leapDays(y);
    } else {
      temp = lunarMonthDays(y, m);
    }
    if (isLeap && m === leap + 1) {
      isLeap = false;
    }
    remain -= temp;
  }
  if (remain === 0 && leap > 0 && m === leap + 1) {
    if (isLeap) {
      isLeap = false;
    } else {
      isLeap = true;
      m -= 1;
    }
  }
  if (remain < 0) {
    remain += temp;
    m -= 1;
  }
  return { year: y, month: m, day: remain + 1, leap: isLeap };
}

/** 农历年月日 → 公历。 */
export function lunarToSolar(
  year: number,
  month: number,
  day: number,
  leap: boolean,
): SolarDate | null {
  if (!inRange(year) || month < 1 || month > 12 || day < 1 || day > 30) {
    return null;
  }
  const length = lunarMonthLength(year, month, leap);
  if (length < 1 || day > length) {
    return null;
  }
  let offset = 0;
  for (let y = 1900; y < year; y++) {
    offset += lunarYearDays(y);
  }
  const leapM = leapMonth(year);
  for (let m = 1; m < month; m++) {
    offset += lunarMonthDays(year, m);
    if (leapM === m) {
      offset += leapDays(year);
    }
  }
  if (leap) {
    offset += lunarMonthDays(year, month);
  }
  offset += day - 1;
  const utc = new Date(Date.UTC(1900, 0, 31) + offset * 86_400_000);
  return {
    year: utc.getUTCFullYear(),
    month: utc.getUTCMonth() + 1,
    day: utc.getUTCDate(),
  };
}

export function lunarDateLabel(lunar: LunarDate): string {
  const month = `${lunar.leap ? '闰' : ''}${MONTH_NAMES[lunar.month - 1] ?? ''}月`;
  return `${month}${DAY_NAMES[lunar.day] ?? ''}`;
}

export function lunarCellLabel(
  year: number,
  month: number,
  day: number,
): string {
  const lunar = solarToLunar(year, month, day);
  return lunar == null ? '' : lunarDateLabel(lunar);
}

export function nextLunarMonth(lunar: LunarDate): LunarDate {
  const leapM = leapMonth(lunar.year);
  if (!lunar.leap && leapM === lunar.month) {
    return { year: lunar.year, month: lunar.month, day: lunar.day, leap: true };
  }
  if (lunar.month === 12) {
    return { year: lunar.year + 1, month: 1, day: lunar.day, leap: false };
  }
  return {
    year: lunar.year,
    month: lunar.month + 1,
    day: lunar.day,
    leap: false,
  };
}

function clampLunarDay(year: number, month: number, day: number, leap: boolean): number {
  const length = lunarMonthLength(year, month, leap);
  if (length < 1) {
    return day;
  }
  return Math.min(day, length);
}

/** 往下一个农历月走，日不够就落到月末。 */
export function stepLunarMonth(solar: SolarDate): SolarDate | null {
  const lunar = solarToLunar(solar.year, solar.month, solar.day);
  if (lunar == null) {
    return null;
  }
  const next = nextLunarMonth(lunar);
  const day = clampLunarDay(next.year, next.month, lunar.day, next.leap);
  return lunarToSolar(next.year, next.month, day, next.leap);
}

/** 往下一个农历年走；没有闰月时改用同名普通月。 */
export function stepLunarYear(solar: SolarDate): SolarDate | null {
  const lunar = solarToLunar(solar.year, solar.month, solar.day);
  if (lunar == null) {
    return null;
  }
  const year = lunar.year + 1;
  const leap = lunar.leap && leapMonth(year) === lunar.month;
  const day = clampLunarDay(year, lunar.month, lunar.day, leap);
  return lunarToSolar(year, lunar.month, day, leap);
}
