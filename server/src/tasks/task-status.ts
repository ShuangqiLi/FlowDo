import { TaskStatus } from './task.enums';

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
