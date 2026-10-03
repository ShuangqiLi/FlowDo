import { TaskPriority } from '../tasks/task.enums';
import {
  buildSpaceStats,
  monthSpaceRollup,
  pickSuggestedFocus,
  sumSpaceStats,
} from './briefing.service';

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

    expect(pickSuggestedFocus([], inboxHigh, 3).map((t) => t.title)).toEqual([
      '一',
      '三',
      '二',
    ]);
  });

  it('is empty when there is nothing in focus and no high inbox tasks', () => {
    expect(pickSuggestedFocus([], [])).toEqual([]);
  });
});

describe('all-space briefing rollups', () => {
  const work = { id: 'work', name: '工作', themeKey: 'hazeBlue' };
  const life = { id: 'life', name: '生活', themeKey: 'mint' };

  it('keeps each space on its own line and sums totals', () => {
    const rows = buildSpaceStats(
      [work, life],
      [
        { spaceId: 'work', status: 'TODO', count: 4 },
        { spaceId: 'work', status: 'FOCUS', count: 1 },
        { spaceId: 'life', status: 'TODO', count: 6 },
        { spaceId: 'life', status: 'DONE', count: 2 },
      ],
      ['work', 'life', 'life'],
      ['work'],
      [
        { spaceId: 'work', count: 2 },
        { spaceId: 'life', count: 1 },
      ],
    );
    expect(rows[0]).toMatchObject({
      id: 'work',
      todo: 4,
      focus: 1,
      completedToday: 1,
      reminders: 2,
    });
    expect(rows[1]).toMatchObject({
      id: 'life',
      todo: 6,
      done: 2,
      completedToday: 2,
      completedYesterday: 0,
    });
    expect(sumSpaceStats(rows)).toMatchObject({
      todo: 10,
      focus: 1,
      done: 2,
      completedToday: 3,
      reminders: 3,
    });
  });

  it('counts completed days per space without merging them', () => {
    const rollup = monthSpaceRollup(
      [work, life],
      [
        { spaceId: 'work', dateKey: '2026-10-01' },
        { spaceId: 'work', dateKey: '2026-10-01' },
        { spaceId: 'life', dateKey: '2026-10-01' },
        { spaceId: 'life', dateKey: '2026-10-02' },
      ],
    );
    expect(rollup[0]).toMatchObject({
      id: 'work',
      completedCount: 2,
      activeDays: 1,
    });
    expect(rollup[1]).toMatchObject({
      id: 'life',
      completedCount: 2,
      activeDays: 2,
    });
  });
});
