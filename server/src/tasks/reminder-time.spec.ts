import { BadRequestException } from '@nestjs/common';
import { RemindRepeat } from './task.enums';
import {
  advanceReminder,
  parseReminderInstant,
  reminderMarks,
  stepReminder,
} from './reminder-time';

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

describe('recurring reminders', () => {
  it('steps a month and a year onto the last valid day', () => {
    const jan31 = new Date(2026, 0, 31, 9, 30, 0, 0);
    const feb = stepReminder(jan31, RemindRepeat.MONTHLY);
    expect(feb.getFullYear()).toBe(2026);
    expect(feb.getMonth()).toBe(1);
    expect(feb.getDate()).toBe(28);
    expect(feb.getHours()).toBe(9);
    expect(feb.getMinutes()).toBe(30);

    const leap = new Date(2024, 1, 29, 8, 0, 0, 0);
    const nextYear = stepReminder(leap, RemindRepeat.YEARLY);
    expect(nextYear.getFullYear()).toBe(2025);
    expect(nextYear.getMonth()).toBe(1);
    expect(nextYear.getDate()).toBe(28);
  });

  it('skips occurrences that are already due', () => {
    const from = new Date(2026, 9, 1, 9, 0, 0, 0);
    const now = new Date(2026, 9, 3, 10, 0, 0, 0);
    const next = advanceReminder(from, RemindRepeat.DAILY, now);
    expect(next.getDate()).toBe(4);
    expect(next.getHours()).toBe(9);
  });

  it('lists only future marks inside the month', () => {
    const nextAt = new Date(2026, 9, 2, 9, 0, 0, 0);
    const now = new Date(2026, 9, 3, 8, 0, 0, 0);
    const marks = reminderMarks(
      nextAt,
      RemindRepeat.DAILY,
      new Date(2026, 9, 1),
      new Date(2026, 9, 5, 23, 59, 0, 0),
      now,
    );
    expect(marks.map((mark) => mark.getDate())).toEqual([3, 4, 5]);
  });
});
