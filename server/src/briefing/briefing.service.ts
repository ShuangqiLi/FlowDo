import { BadRequestException, Injectable } from '@nestjs/common';
import {
  daysInMonth,
  DEFAULT_TZ_OFFSET_MINUTES,
  monthDateKey,
  monthRange,
  startOfZonedDay,
  toDateKey,
} from '../clock/zone';
import { InstanceService } from '../instance/instance.service';
import { PrismaService } from '../prisma/prisma.service';
import { reminderMarks } from '../tasks/reminder-time';
import { RemindRepeat, TaskPriority, TaskStatus } from '../tasks/task.enums';

const PRIORITY_ORDER: Record<TaskPriority, number> = {
  HIGH: 0,
  MEDIUM: 1,
  LOW: 2,
  REMINDER: 3,
  NONE: 4,
};

const DEFAULT_SUGGEST_LIMIT = 3;

type RankedTask = { priority: string; updatedAt: Date };

export function comparePriorityThenRecent(
  a: RankedTask,
  b: RankedTask,
): number {
  const p =
    (PRIORITY_ORDER[a.priority as TaskPriority] ?? 9) -
    (PRIORITY_ORDER[b.priority as TaskPriority] ?? 9);
  if (p !== 0) {
    return p;
  }
  return b.updatedAt.getTime() - a.updatedAt.getTime();
}

/** 有聚焦就按优先级推荐聚焦；没有才从任务池里拿几件高优先级；都没有就空。 */
export function pickSuggestedFocus<T extends RankedTask>(
  focused: T[],
  inboxHigh: T[],
  limit = DEFAULT_SUGGEST_LIMIT,
): T[] {
  if (focused.length > 0) {
    return [...focused].sort(comparePriorityThenRecent);
  }
  return [...inboxHigh].sort(comparePriorityThenRecent).slice(0, limit);
}

export type SpaceRow = { id: string; name: string; themeKey: string };

export type SpaceStats = SpaceRow & {
  todo: number;
  focus: number;
  done: number;
  archived: number;
  reminders: number;
  completedToday: number;
  completedYesterday: number;
};

export function buildSpaceStats(
  spaces: SpaceRow[],
  statusCounts: Array<{ spaceId: string; status: string; count: number }>,
  completedTodaySpaceIds: string[],
  completedYesterdaySpaceIds: string[],
  reminderCounts: Array<{ spaceId: string; count: number }>,
): SpaceStats[] {
  const byStatus = new Map<string, Record<string, number>>();
  for (const row of statusCounts) {
    const cur = byStatus.get(row.spaceId) ?? {};
    cur[row.status] = row.count;
    byStatus.set(row.spaceId, cur);
  }
  const today = countKeys(completedTodaySpaceIds);
  const yesterday = countKeys(completedYesterdaySpaceIds);
  const reminders = new Map(
    reminderCounts.map((row) => [row.spaceId, row.count]),
  );
  return spaces.map((space) => {
    const st = byStatus.get(space.id) ?? {};
    return {
      ...space,
      todo: st.TODO ?? 0,
      focus: st.FOCUS ?? 0,
      done: st.DONE ?? 0,
      archived: st.ARCHIVED ?? 0,
      reminders: reminders.get(space.id) ?? 0,
      completedToday: today.get(space.id) ?? 0,
      completedYesterday: yesterday.get(space.id) ?? 0,
    };
  });
}

export function sumSpaceStats(rows: SpaceStats[]) {
  return rows.reduce(
    (acc, row) => ({
      todo: acc.todo + row.todo,
      focus: acc.focus + row.focus,
      done: acc.done + row.done,
      archived: acc.archived + row.archived,
      reminders: acc.reminders + row.reminders,
      completedToday: acc.completedToday + row.completedToday,
      completedYesterday: acc.completedYesterday + row.completedYesterday,
    }),
    {
      todo: 0,
      focus: 0,
      done: 0,
      archived: 0,
      reminders: 0,
      completedToday: 0,
      completedYesterday: 0,
    },
  );
}

export function monthSpaceRollup(
  spaces: SpaceRow[],
  completed: Array<{ spaceId: string; dateKey: string }>,
) {
  const bySpace = new Map<string, { count: number; days: Set<string> }>();
  for (const row of completed) {
    const cur = bySpace.get(row.spaceId) ?? {
      count: 0,
      days: new Set<string>(),
    };
    cur.count += 1;
    cur.days.add(row.dateKey);
    bySpace.set(row.spaceId, cur);
  }
  return spaces.map((space) => {
    const cur = bySpace.get(space.id);
    return {
      ...space,
      completedCount: cur?.count ?? 0,
      activeDays: cur?.days.size ?? 0,
    };
  });
}

function countKeys(ids: string[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const id of ids) {
    map.set(id, (map.get(id) ?? 0) + 1);
  }
  return map;
}

@Injectable()
export class BriefingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly instance: InstanceService,
  ) {}

  async today(tzOffset = DEFAULT_TZ_OFFSET_MINUTES) {
    const now = new Date();
    const startOfToday = startOfZonedDay(now, tzOffset);
    const space = await this.instance.activeSpace();
    const startOfYesterday = new Date(
      startOfToday.getTime() - 24 * 60 * 60 * 1000,
    );

    const [
      spaces,
      statusGroups,
      reminderGroups,
      completedToday,
      completedYesterday,
      focus,
      inboxHigh,
    ] = await Promise.all([
      this.prisma.space.findMany({ orderBy: { createdAt: 'asc' } }),
      this.prisma.task.groupBy({
        by: ['spaceId', 'status'],
        _count: { _all: true },
      }),
      this.prisma.task.groupBy({
        by: ['spaceId'],
        where: {
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
          remindAt: { gt: now },
        },
        _count: { _all: true },
      }),
      this.prisma.task.findMany({
        where: { completedAt: { gte: startOfToday } },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.task.findMany({
        where: {
          completedAt: { gte: startOfYesterday, lt: startOfToday },
        },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.task.findMany({
        where: { spaceId: space.id, status: TaskStatus.FOCUS },
      }),
      this.prisma.task.findMany({
        where: {
          spaceId: space.id,
          status: TaskStatus.TODO,
          priority: TaskPriority.HIGH,
        },
      }),
    ]);

    const spaceStats = buildSpaceStats(
      spaces.map((row) => ({
        id: row.id,
        name: row.name,
        themeKey: row.themeKey,
      })),
      statusGroups.map((row) => ({
        spaceId: row.spaceId,
        status: row.status,
        count: row._count._all,
      })),
      completedToday.map((row) => row.spaceId),
      completedYesterday.map((row) => row.spaceId),
      reminderGroups.map((row) => ({
        spaceId: row.spaceId,
        count: row._count._all,
      })),
    );
    const totals = sumSpaceStats(spaceStats);
    const focusedTasks = [...focus].sort(comparePriorityThenRecent);
    const suggestedFocus = pickSuggestedFocus(
      focusedTasks,
      inboxHigh,
      space.focusLimit ?? DEFAULT_SUGGEST_LIMIT,
    );

    return {
      date: toDateKey(now, tzOffset),
      counts: {
        todo: totals.todo,
        focus: totals.focus,
        done: totals.done,
        archived: totals.archived,
        reminders: totals.reminders,
        completedToday: totals.completedToday,
        completedYesterday: totals.completedYesterday,
        total: totals.todo + totals.focus + totals.done + totals.archived,
      },
      spaces: spaceStats,
      focusedTasks,
      suggestedFocus,
      completedToday,
      completedYesterday,
      pendingArchive: totals.done,
    };
  }

  async month(
    year: number,
    month: number,
    tzOffset = DEFAULT_TZ_OFFSET_MINUTES,
  ) {
    if (
      !Number.isInteger(year) ||
      !Number.isInteger(month) ||
      month < 1 ||
      month > 12
    ) {
      throw new BadRequestException('这个月份不太对');
    }
    const { start, end } = monthRange(year, month, tzOffset);
    const now = new Date();
    const startKey = monthDateKey(year, month, 1);
    const endKey = monthDateKey(year, month, daysInMonth(year, month));
    const [spaces, completed, repeating, once] = await Promise.all([
      this.prisma.space.findMany({ orderBy: { createdAt: 'asc' } }),
      this.prisma.task.findMany({
        where: { completedAt: { gte: start, lte: end } },
        orderBy: { completedAt: 'desc' },
      }),
      this.prisma.task.findMany({
        where: {
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          remindRepeat: { not: RemindRepeat.ONCE },
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
          remindAt: { lte: end },
        },
        orderBy: { remindAt: 'asc' },
      }),
      this.prisma.task.findMany({
        where: {
          priority: TaskPriority.REMINDER,
          remindedAt: null,
          remindRepeat: RemindRepeat.ONCE,
          status: { in: [TaskStatus.TODO, TaskStatus.FOCUS] },
          remindAt: { gt: now, lte: end },
        },
        orderBy: { remindAt: 'asc' },
      }),
    ]);

    const dayCounts = new Map<string, number>();
    const dayTasks = new Map<string, typeof completed>();
    for (const row of completed) {
      if (!row.completedAt) {
        continue;
      }
      const key = toDateKey(row.completedAt, tzOffset);
      dayCounts.set(key, (dayCounts.get(key) ?? 0) + 1);
      const list = dayTasks.get(key) ?? [];
      list.push(row);
      dayTasks.set(key, list);
    }

    const dayReminders = new Map<string, Array<(typeof once)[number]>>();
    const putReminder = (row: (typeof once)[number], at: Date) => {
      const key = toDateKey(at, tzOffset);
      if (key < startKey || key > endKey) {
        return;
      }
      const list = dayReminders.get(key) ?? [];
      list.push({ ...row, remindAt: at });
      dayReminders.set(key, list);
    };
    for (const row of once) {
      if (row.remindAt) {
        putReminder(row, row.remindAt);
      }
    }
    for (const row of repeating) {
      if (!row.remindAt) {
        continue;
      }
      for (const at of reminderMarks(
        row.remindAt,
        row.remindRepeat as RemindRepeat,
        start,
        end,
        now,
      )) {
        putReminder(row, at);
      }
    }

    const length = daysInMonth(year, month);
    const days = Array.from({ length }, (_, i) => {
      const key = monthDateKey(year, month, i + 1);
      return {
        date: key,
        count: dayCounts.get(key) ?? 0,
        tasks: dayTasks.get(key) ?? [],
        reminders: dayReminders.get(key) ?? [],
      };
    });

    const spaceRows = spaces.map((row) => ({
      id: row.id,
      name: row.name,
      themeKey: row.themeKey,
    }));

    return {
      year,
      month,
      completedCount: days.reduce((sum, day) => sum + day.count, 0),
      activeDays: days.filter((day) => day.count > 0).length,
      spaces: monthSpaceRollup(
        spaceRows,
        completed.flatMap((row) =>
          row.completedAt
            ? [
                {
                  spaceId: row.spaceId,
                  dateKey: toDateKey(row.completedAt, tzOffset),
                },
              ]
            : [],
        ),
      ),
      days,
    };
  }
}
