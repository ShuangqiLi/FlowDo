import { BadRequestException } from '@nestjs/common';
import {
  daysInMonth,
  monthDateKey,
  monthRange,
  parseTzOffset,
  startOfZonedDay,
  toDateKey,
} from './zone';

describe('client timezone date keys', () => {
  it('defaults to China when the client omits an offset', () => {
    expect(parseTzOffset(undefined)).toBe(480);
    expect(parseTzOffset('')).toBe(480);
  });

  it('rejects an offset that is not a whole minute in range', () => {
    expect(() => parseTzOffset('8.5')).toThrow(BadRequestException);
    expect(() => parseTzOffset('9999')).toThrow(BadRequestException);
  });

  it('puts an early-morning China reminder on tomorrow, not UTC today', () => {
    const at = new Date('2026-10-03T16:30:00.000Z');
    expect(toDateKey(at, 0)).toBe('2026-10-03');
    expect(toDateKey(at, 480)).toBe('2026-10-04');
  });

  it('keeps October 1 before 08:00 China inside the October query window', () => {
    const { start, end } = monthRange(2026, 10, 480);
    const early = new Date('2026-09-30T23:30:00.000Z');
    expect(early.getTime()).toBeGreaterThanOrEqual(start.getTime());
    expect(early.getTime()).toBeLessThanOrEqual(end.getTime());
    expect(toDateKey(early, 480)).toBe('2026-10-01');
    expect(toDateKey(end, 480)).toBe('2026-10-31');
  });

  it('starts today at local midnight, not the server clock midnight', () => {
    const now = new Date('2026-10-03T16:30:00.000Z');
    const start = startOfZonedDay(now, 480);
    expect(start.toISOString()).toBe('2026-10-03T16:00:00.000Z');
    expect(toDateKey(now, 480)).toBe('2026-10-04');
  });

  it('builds month keys without using the server locale', () => {
    expect(monthDateKey(2026, 10, 4)).toBe('2026-10-04');
    expect(daysInMonth(2026, 2)).toBe(28);
    expect(daysInMonth(2024, 2)).toBe(29);
  });
});
