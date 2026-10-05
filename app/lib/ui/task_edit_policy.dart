import '../widgets/priority_selector.dart';

/// 各状态下能改什么：提醒进了聚焦就不能回任务池，也不能再和普通任务互转。
abstract final class TaskEditPolicy {
  static bool canEditContent(String status) => status != 'ARCHIVED';

  static bool canPickPriority(String status, String priority) {
    if (status == 'TODO') {
      return true;
    }
    if (status == 'FOCUS' && priority != 'REMINDER') {
      return true;
    }
    return false;
  }

  static List<String> pickablePriorities(String status, String current) {
    if (status == 'TODO') {
      return List<String>.of(priorityOrder);
    }
    if (status == 'FOCUS' && current != 'REMINDER') {
      return [
        for (final priority in priorityOrder)
          if (priority != 'REMINDER') priority,
      ];
    }
    return [current];
  }

  static bool canReschedule(String status) => status == 'TODO';

  static bool canReturnToPool(String status, String priority) {
    if (status == 'DONE') {
      return true;
    }
    if (status == 'FOCUS' && priority != 'REMINDER') {
      return true;
    }
    return false;
  }
}
