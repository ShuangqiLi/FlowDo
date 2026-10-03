import { BadRequestException } from '@nestjs/common';
import { parseReminderInstant } from './reminder-time';

describe('parseReminderInstant', () => {
  const now = new Date('2026-10-03T06:30:20.000Z');

  it('keeps a later minute and drops the seconds', () => {
    const at = parseReminderInstant('2026-10-03T06:31:45.000Z', now);
    expect(at.toISOString()).toBe('2026-10-03T06:31:00.000Z');
  });

  it('rejects a minute that is not later than now', () => {
    expect(() => parseReminderInstant('2026-10-03T06:30:00.000Z', now)).toThrow(
      BadRequestException,
    );
  });
});
