import { canTransition } from './task-status';
import { TaskStatus } from './task.enums';

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
});
