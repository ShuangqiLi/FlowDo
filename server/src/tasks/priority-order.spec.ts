import { TaskPriority, TaskStatus } from './task.enums';
import { comparePriorityThenRecent, priorityRank } from './priority-order';

describe('priorityRank', () => {
  it('puts reminders first in focus and last in the inbox', () => {
    expect(priorityRank(TaskPriority.REMINDER, TaskStatus.FOCUS)).toBe(0);
    expect(priorityRank(TaskPriority.HIGH, TaskStatus.FOCUS)).toBe(1);
    expect(priorityRank(TaskPriority.HIGH, TaskStatus.TODO)).toBe(0);
    expect(priorityRank(TaskPriority.NONE, TaskStatus.TODO)).toBe(3);
    expect(priorityRank(TaskPriority.REMINDER, TaskStatus.TODO)).toBe(4);
  });
});

describe('comparePriorityThenRecent', () => {
  const older = new Date('2026-09-20');
  const newer = new Date('2026-09-25');

  it('orders focused reminders ahead of high priority', () => {
    const sorted = [
      { priority: TaskPriority.HIGH, updatedAt: newer },
      { priority: TaskPriority.REMINDER, updatedAt: older },
      { priority: TaskPriority.NONE, updatedAt: newer },
    ].sort((a, b) => comparePriorityThenRecent(a, b, TaskStatus.FOCUS));
    expect(sorted.map((row) => row.priority)).toEqual([
      TaskPriority.REMINDER,
      TaskPriority.HIGH,
      TaskPriority.NONE,
    ]);
  });

  it('orders inbox reminders after no-priority tasks', () => {
    const sorted = [
      { priority: TaskPriority.REMINDER, updatedAt: newer },
      { priority: TaskPriority.NONE, updatedAt: older },
      { priority: TaskPriority.LOW, updatedAt: newer },
    ].sort((a, b) => comparePriorityThenRecent(a, b, TaskStatus.TODO));
    expect(sorted.map((row) => row.priority)).toEqual([
      TaskPriority.LOW,
      TaskPriority.NONE,
      TaskPriority.REMINDER,
    ]);
  });
});
