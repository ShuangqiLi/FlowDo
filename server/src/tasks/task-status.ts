import { TaskPriority, TaskStatus } from './task.enums';

const ALLOWED: Record<TaskStatus, TaskStatus[]> = {
  [TaskStatus.TODO]: [TaskStatus.FOCUS],
  [TaskStatus.FOCUS]: [TaskStatus.TODO, TaskStatus.DONE],
  [TaskStatus.DONE]: [TaskStatus.TODO, TaskStatus.ARCHIVED],
  [TaskStatus.ARCHIVED]: [],
};

export function canTransition(
  from: string,
  to: string,
  priority?: string,
): boolean {
  if (from === to) {
    return true;
  }
  if (
    from === TaskStatus.FOCUS &&
    to === TaskStatus.TODO &&
    priority === TaskPriority.REMINDER
  ) {
    return false;
  }
  return (ALLOWED[from as TaskStatus] ?? []).includes(to as TaskStatus);
}

/** 提醒任务只能到点自动进聚焦，不能手滑或改状态送进去。 */
export function canEnterFocusManually(priority: string): boolean {
  return priority !== TaskPriority.REMINDER;
}

/** 进了聚焦 / 完成 / 归档后，不能再在提醒和普通任务之间切换。 */
export function canChangePriority(
  status: string,
  from: string,
  to: string,
): boolean {
  if (from === to) {
    return true;
  }
  if (status === TaskStatus.ARCHIVED || status === TaskStatus.DONE) {
    return false;
  }
  if (status === TaskStatus.FOCUS) {
    return from !== TaskPriority.REMINDER && to !== TaskPriority.REMINDER;
  }
  return true;
}
