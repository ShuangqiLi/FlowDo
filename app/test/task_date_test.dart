import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/task.dart';

Task _task({
  required String status,
  required DateTime createdAt,
  DateTime? completedAt,
  DateTime? archivedAt,
}) {
  return Task(
    id: '1',
    title: '喂猫',
    status: status,
    priority: 'MEDIUM',
    createdAt: createdAt,
    updatedAt: createdAt,
    completedAt: completedAt,
    archivedAt: archivedAt,
  );
}

void main() {
  final now = DateTime(2026, 9, 25, 15);

  test('inbox tasks use the created date', () {
    expect(
      _task(status: 'TODO', createdAt: DateTime(2026, 9, 25, 8)).listDateLabel(now),
      '今天加入',
    );
    expect(
      _task(status: 'TODO', createdAt: DateTime(2026, 9, 24, 22)).listDateLabel(now),
      '昨天加入',
    );
    expect(
      _task(status: 'TODO', createdAt: DateTime(2026, 8, 3)).listDateLabel(now),
      '8月3日加入',
    );
    expect(
      _task(status: 'TODO', createdAt: DateTime(2025, 12, 31)).listDateLabel(now),
      '2025年12月31日加入',
    );
  });

  test('done and archived tasks use completedAt and archivedAt', () {
    expect(
      _task(
        status: 'DONE',
        createdAt: DateTime(2026, 9, 1),
        completedAt: DateTime(2026, 9, 20),
      ).listDateLabel(now),
      '9月20日搞定',
    );
    expect(
      _task(
        status: 'ARCHIVED',
        createdAt: DateTime(2026, 9, 1),
        archivedAt: DateTime(2026, 9, 22),
      ).listDateLabel(now),
      '9月22日归档',
    );
  });

  test('archived keep hint can be permanent', () {
    final task = _task(
      status: 'ARCHIVED',
      createdAt: DateTime(2026, 9, 1),
      archivedAt: DateTime(2026, 9, 22),
    );
    expect(task.archiveKeepHint(0, now), '9月22日归档 · 永久保留');
    expect(task.archiveKeepHint(30, now).contains('自动清掉'), isTrue);
    expect(task.archiveKeepHint(30, now).contains('永久保留'), isFalse);
  });
}
