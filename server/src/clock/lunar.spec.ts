import { solarToLunar, lunarToSolar, lunarDateLabel, stepLunarYear } from './lunar';

describe('lunar calendar', () => {
  it('converts mid-autumn 2026', () => {
    const lunar = solarToLunar(2026, 9, 25);
    expect(lunar).toEqual({ year: 2026, month: 8, day: 15, leap: false });
    expect(lunarDateLabel(lunar!)).toBe('八月十五');
    expect(lunarToSolar(2026, 8, 15, false)).toEqual({
      year: 2026,
      month: 9,
      day: 25,
    });
  });

  it('converts spring festival 2026', () => {
    expect(solarToLunar(2026, 2, 17)).toEqual({
      year: 2026,
      month: 1,
      day: 1,
      leap: false,
    });
    expect(lunarDateLabel(solarToLunar(2026, 2, 17)!)).toBe('正月初一');
  });

  it('round-trips a leap month', () => {
    const leapStart = solarToLunar(2025, 7, 25);
    expect(leapStart).toMatchObject({ month: 6, leap: true, day: 1 });
    expect(lunarToSolar(leapStart!.year, 6, 1, true)).toEqual({
      year: 2025,
      month: 7,
      day: 25,
    });
  });

  it('steps a lunar year onto the next mid-autumn', () => {
    const next = stepLunarYear({ year: 2026, month: 9, day: 25 });
    expect(next).toEqual({ year: 2027, month: 9, day: 15 });
  });
});
