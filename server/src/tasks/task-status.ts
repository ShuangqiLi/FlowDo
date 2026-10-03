import { TaskPriority, TaskStatus } from './task.enums';

const ALLOWED: Record<TaskStatus, TaskStatus[]> = {
  [TaskStatus.TODO]: [TaskStatus.FOCUS],
  [TaskStatus.FOCUS]: [TaskStatus.TODO, TaskStatus.DONE],
  [TaskStatus.DONE]: [TaskStatus.TODO, TaskStatus.ARCHIVED],
  [TaskStatus.ARCHIVED]: [],
};

export function canTransition(from: string, to: string): boolean {
  if (from === to) {
    return true;
  }
  return (ALLOWED[from as TaskStatus] ?? []).includes(to as TaskStatus);
}

/** 提醒任务只能到点自动进聚焦，不能手滑或改状态送进去。 */
export function canEnterFocusManually(priority: string): boolean {
  return priority !== TaskPriority.REMINDER;
}
