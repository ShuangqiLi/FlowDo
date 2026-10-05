import '../widgets/priority_selector.dart';

/// 做不到的操作不要发出去。各状态下界面上只留下能成功的那几项。
abstract final class TaskEditPolicy {
  static bool canEditContent(String status) =>
      status == 'TODO' || status == 'FOCUS';

  static bool canMoveSpace(String status) =>
      status == 'TODO' || status == 'FOCUS';

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
      return const ['HIGH', 'MEDIUM', 'LOW'];
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
