import {
  canChangePriority,
  canEnterFocusManually,
  canTransition,
} from './task-status';
import { TaskPriority, TaskStatus } from './task.enums';

describe('canTransition', () => {
  it('sends inbox to focus, not done', () => {
    expect(canTransition(TaskStatus.TODO, TaskStatus.FOCUS)).toBe(true);
    expect(canTransition(TaskStatus.TODO, TaskStatus.DONE)).toBe(false);
    expect(canTransition(TaskStatus.TODO, TaskStatus.ARCHIVED)).toBe(false);
  });

  it('sends done tasks back to inbox, not focus', () => {
    expect(canTransition(TaskStatus.DONE, TaskStatus.TODO)).toBe(true);
    expect(canTransition(TaskStatus.DONE, TaskStatus.FOCUS)).toBe(false);
  });

  it('keeps archived tasks read-only', () => {
    expect(canTransition(TaskStatus.ARCHIVED, TaskStatus.TODO)).toBe(false);
    expect(canTransition(TaskStatus.ARCHIVED, TaskStatus.FOCUS)).toBe(false);
    expect(canTransition(TaskStatus.ARCHIVED, TaskStatus.DONE)).toBe(false);
  });

  it('keeps reminder tasks in focus instead of sending them back to the pool', () => {
    expect(
      canTransition(TaskStatus.FOCUS, TaskStatus.TODO, TaskPriority.REMINDER),
    ).toBe(false);
    expect(
      canTransition(TaskStatus.FOCUS, TaskStatus.DONE, TaskPriority.REMINDER),
    ).toBe(true);
    expect(
      canTransition(TaskStatus.FOCUS, TaskStatus.TODO, TaskPriority.HIGH),
    ).toBe(true);
  });
});

describe('canEnterFocusManually', () => {
  it('lets ordinary tasks into focus', () => {
    expect(canEnterFocusManually(TaskPriority.HIGH)).toBe(true);
    expect(canEnterFocusManually(TaskPriority.NONE)).toBe(true);
  });

  it('keeps reminder tasks out until they fire', () => {
    expect(canEnterFocusManually(TaskPriority.REMINDER)).toBe(false);
  });
});

describe('canChangePriority', () => {
  it('lets inbox tasks become reminders or ordinary tasks', () => {
    expect(
      canChangePriority(TaskStatus.TODO, TaskPriority.NONE, TaskPriority.REMINDER),
    ).toBe(true);
    expect(
      canChangePriority(TaskStatus.TODO, TaskPriority.REMINDER, TaskPriority.HIGH),
    ).toBe(true);
  });

  it('lets focused ordinary tasks change rank but not become reminders', () => {
    expect(
      canChangePriority(TaskStatus.FOCUS, TaskPriority.HIGH, TaskPriority.LOW),
    ).toBe(true);
    expect(
      canChangePriority(
        TaskStatus.FOCUS,
        TaskPriority.HIGH,
        TaskPriority.REMINDER,
      ),
    ).toBe(false);
    expect(
      canChangePriority(
        TaskStatus.FOCUS,
        TaskPriority.REMINDER,
        TaskPriority.NONE,
      ),
    ).toBe(false);
  });

  it('locks done and archived priorities', () => {
    expect(
      canChangePriority(TaskStatus.DONE, TaskPriority.HIGH, TaskPriority.LOW),
    ).toBe(false);
    expect(
      canChangePriority(
        TaskStatus.ARCHIVED,
        TaskPriority.NONE,
        TaskPriority.HIGH,
      ),
    ).toBe(false);
  });
});
