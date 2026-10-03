import { TaskPriority, TaskStatus } from './task.enums';

/** 聚焦里提醒置顶；任务池里提醒垫底。 */
export function priorityRank(priority: string, status?: string): number {
  if (status === TaskStatus.FOCUS) {
    switch (priority) {
      case TaskPriority.REMINDER:
        return 0;
      case TaskPriority.HIGH:
        return 1;
      case TaskPriority.MEDIUM:
        return 2;
      case TaskPriority.LOW:
        return 3;
      case TaskPriority.NONE:
        return 4;
      default:
        return 9;
    }
  }
  switch (priority) {
    case TaskPriority.HIGH:
      return 0;
    case TaskPriority.MEDIUM:
      return 1;
    case TaskPriority.LOW:
      return 2;
    case TaskPriority.NONE:
      return 3;
    case TaskPriority.REMINDER:
      return 4;
    default:
      return 9;
  }
}

export function comparePriorityThenRecent(
  a: { priority: string; updatedAt: Date },
  b: { priority: string; updatedAt: Date },
  status?: string,
): number {
  const byPriority = priorityRank(a.priority, status) - priorityRank(b.priority, status);
  if (byPriority !== 0) {
    return byPriority;
  }
  return b.updatedAt.getTime() - a.updatedAt.getTime();
}
