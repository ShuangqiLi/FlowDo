import {
  formatLunarDate,
  initialNextDate,
  lunarDayLabel,
  lunarToSolar,
  nextOccurrence,
  occurrenceKeysInMonth,
  toDateKey,
  type ReminderRule,
} from './lunar-date';

describe('lunar dates', () => {
  it('maps lunar new year 2026 to Feb 17', () => {
    const solar = lunarToSolar(2026, 1, 1, false);
    expect(solar && toDateKey(solar)).toBe('2026-02-17');
  });

  it('falls back to the last day when the lunar day is missing', () => {
    const solar = lunarToSolar(2026, 2, 30, false);
    expect(solar && toDateKey(solar)).toBe(
      toDateKey(lunarToSolar(2026, 2, 29, false)!),
    );
  });

  it('uses the leap month when that year has one', () => {
    expect(toDateKey(lunarToSolar(2025, 6, 1, true)!)).toBe('2025-07-25');
  });

  it('uses the plain month when the requested leap month is absent', () => {
    expect(toDateKey(lunarToSolar(2026, 6, 1, true)!)).toBe(
      toDateKey(lunarToSolar(2026, 6, 1, false)!),
    );
  });

  it('labels the first lunar day with the month name', () => {
    expect(lunarDayLabel(new Date(2026, 1, 17))).toBe('正月');
    expect(lunarDayLabel(new Date(2026, 9, 1))).toMatch(/廿|初|十/);
  });

  it('formats a stored lunar date', () => {
    expect(formatLunarDate(1, 1, false)).toBe('正月初一');
    expect(formatLunarDate(6, 15, true)).toBe('闰六月十五');
  });

  it('rolls a Feb 29 yearly reminder onto Feb 28', () => {
    const rule: ReminderRule = {
      calendar: 'SOLAR',
      recurrence: 'YEARLY',
      nextDate: new Date(2024, 1, 29),
      lunarMonth: null,
      lunarDay: null,
      leapMonth: false,
    };
    expect(toDateKey(nextOccurrence(rule, new Date(2025, 0, 1)))).toBe(
      '2025-02-28',
    );
  });

  it('places a yearly lunar reminder on its solar day', () => {
    const next = initialNextDate(
      {
        calendar: 'LUNAR',
        recurrence: 'YEARLY',
        lunarMonth: 1,
        lunarDay: 1,
      },
      new Date(2026, 0, 1),
    );
    expect(toDateKey(next)).toBe('2026-02-17');
    const keys = occurrenceKeysInMonth(
      {
        calendar: 'LUNAR',
        recurrence: 'YEARLY',
        nextDate: next,
        lunarMonth: 1,
        lunarDay: 1,
        leapMonth: false,
      },
      2026,
      2,
    );
    expect(keys).toEqual(['2026-02-17']);
  });
});
