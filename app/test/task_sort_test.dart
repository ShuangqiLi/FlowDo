import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/ui/task_sort.dart';

Task _task(String priority, DateTime updatedAt) {
  return Task(
    id: priority,
    title: priority,
    status: 'TODO',
    priority: priority,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

void main() {
  final older = DateTime(2026, 9, 20);
  final newer = DateTime(2026, 9, 25);

  test('focus lists reminders first', () {
    final sorted = [
      _task('HIGH', newer),
      _task('REMINDER', older),
      _task('NONE', newer),
    ]..sort((a, b) => compareTasksByPriorityThenRecent(a, b, 'FOCUS'));
    expect(sorted.map((task) => task.priority).toList(), [
      'REMINDER',
      'HIGH',
      'NONE',
    ]);
  });

  test('inbox lists reminders last', () {
    final sorted = [
      _task('REMINDER', newer),
      _task('NONE', older),
      _task('LOW', newer),
    ]..sort((a, b) => compareTasksByPriorityThenRecent(a, b, 'TODO'));
    expect(sorted.map((task) => task.priority).toList(), [
      'LOW',
      'NONE',
      'REMINDER',
    ]);
  });
}
