import { TaskPriority } from '../tasks/task.enums';
import { pickSuggestedFocus } from './briefing.service';

function task(title: string, priority: TaskPriority, updatedAt: Date) {
  return { title, priority, updatedAt };
}

describe('pickSuggestedFocus', () => {
  const older = new Date('2026-09-20');
  const newer = new Date('2026-09-25');

  it('uses focused tasks in priority order when any exist', () => {
    const focused = [
      task('中', TaskPriority.MEDIUM, newer),
      task('低', TaskPriority.LOW, newer),
      task('高', TaskPriority.HIGH, older),
    ];
    const inboxHigh = [task('池子高', TaskPriority.HIGH, newer)];

    const picked = pickSuggestedFocus(focused, inboxHigh);

    expect(picked.map((t) => t.title)).toEqual(['高', '中', '低']);
  });

  it('does not fall back to the inbox while anything is in focus', () => {
    const focused = [task('手头这件事', TaskPriority.LOW, newer)];
    const inboxHigh = [task('池子高', TaskPriority.HIGH, newer)];

    expect(pickSuggestedFocus(focused, inboxHigh).map((t) => t.title)).toEqual([
      '手头这件事',
    ]);
  });

  it('recommends a few high-priority inbox tasks when focus is empty', () => {
    const inboxHigh = [
      task('一', TaskPriority.HIGH, newer),
      task('二', TaskPriority.HIGH, older),
      task('三', TaskPriority.HIGH, new Date('2026-09-21')),
      task('四', TaskPriority.HIGH, new Date('2026-09-19')),
    ];

    expect(
      pickSuggestedFocus([], inboxHigh, 3).map((t) => t.title),
    ).toEqual(['一', '三', '二']);
  });

  it('is empty when there is nothing in focus and no high inbox tasks', () => {
    expect(pickSuggestedFocus([], [])).toEqual([]);
  });
});
