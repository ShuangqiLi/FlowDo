import { DEFAULT_TZ_OFFSET_MINUTES } from './zone';
import { nextCronOccurrence, normalizeCron, parseCron } from './cron';

describe('cron', () => {
  it('normalizes five fields', () => {
    expect(normalizeCron('  0   9 * * 1-5 ')).toBe('0 9 * * 1-5');
  });

  it('rejects the wrong number of fields', () => {
    expect(() => parseCron('0 9 * *')).toThrow('crontab 用五段');
  });

  it('finds the next weekday morning in China time', () => {
    const fridayNight = new Date('2026-10-02T16:00:00.000Z'); // 周六 00:00 +8
    const next = nextCronOccurrence(
      '0 9 * * 1-5',
      fridayNight,
      DEFAULT_TZ_OFFSET_MINUTES,
    );
    expect(next.toISOString()).toBe('2026-10-05T01:00:00.000Z'); // 周一 09:00 +8
  });

  it('steps a daily 9:00 cron', () => {
    const justAfter = new Date('2026-10-03T01:00:00.000Z'); // 09:00 +8
    const next = nextCronOccurrence(
      '0 9 * * *',
      justAfter,
      DEFAULT_TZ_OFFSET_MINUTES,
    );
    expect(next.toISOString()).toBe('2026-10-04T01:00:00.000Z');
  });
});
