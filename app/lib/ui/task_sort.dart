import '../models/task.dart';

int priorityRank(String priority, String status) {
  if (status == 'FOCUS') {
    return switch (priority) {
      'REMINDER' => 0,
      'HIGH' => 1,
      'MEDIUM' => 2,
      'LOW' => 3,
      'NONE' => 4,
      _ => 9,
    };
  }
  return switch (priority) {
    'HIGH' => 0,
    'MEDIUM' => 1,
    'LOW' => 2,
    'NONE' => 3,
    'REMINDER' => 4,
    _ => 9,
  };
}

int compareTasksByPriorityThenRecent(Task a, Task b, String status) {
  final byPriority =
      priorityRank(a.priority, status) - priorityRank(b.priority, status);
  if (byPriority != 0) {
    return byPriority;
  }
  return b.updatedAt.compareTo(a.updatedAt);
}
