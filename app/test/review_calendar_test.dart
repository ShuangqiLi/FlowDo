import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/briefing.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/ui/review_calendar.dart';

void main() {
  testWidgets('month calendar fills the current month grid', (tester) async {
    final days = [
      ReviewDay(date: '2026-09-01', count: 1),
      ReviewDay(date: '2026-09-15', count: 7),
      ReviewDay(date: '2026-09-25', count: 0),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: 2026,
            month: 9,
            days: days,
            todayKey: '2026-09-25',
          ),
        ),
      ),
    );

    expect(find.text('15'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.byType(MonthReviewCalendar), findsOneWidget);
  });

  test('briefing json parses month review', () {
    final briefing = Briefing.fromJson({
      'date': '2026-09-25',
      'counts': {'todo': 1, 'focus': 0, 'done': 2, 'archived': 0},
      'focusedTasks': [],
      'suggestedFocus': [],
      'completedToday': [],
      'completedYesterday': [],
      'pendingArchive': 2,
      'monthReview': {
        'year': 2026,
        'month': 9,
        'completedCount': 10,
        'activeDays': 5,
        'days': [
          {
            'date': '2026-09-22',
            'count': 1,
            'tasks': [
              {
                'id': 't1',
                'title': '浇花',
                'status': 'DONE',
                'priority': 'MEDIUM',
                'createdAt': '2026-09-22T10:00:00.000Z',
                'updatedAt': '2026-09-22T12:00:00.000Z',
                'completedAt': '2026-09-22T12:00:00.000Z',
              },
            ],
          },
        ],
      },
    });

    expect(briefing.monthReview.month, 9);
    expect(briefing.monthReview.activeDays, 5);
    expect(briefing.monthReview.days.first.tasks.single.title, '浇花');
  });

  testWidgets('tapping a month day opens an anchored day menu', (tester) async {
    final days = [
      ReviewDay(
        date: '2026-09-24',
        count: 1,
        tasks: [
          Task(
            id: '1',
            title: '浇花',
            status: 'DONE',
            priority: 'MEDIUM',
            createdAt: DateTime(2026, 9, 24),
            updatedAt: DateTime(2026, 9, 24),
            completedAt: DateTime(2026, 9, 24),
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: 2026,
            month: 9,
            days: days,
            todayKey: '2026-09-24',
            onDayTap: (anchor, day) {
              showReviewDayPopover(
                anchor,
                day: day,
                onOpenTask: (_) {},
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('24'));
    await tester.pumpAndSettle();
    expect(find.text('浇花'), findsOneWidget);
    expect(find.textContaining('星期四'), findsOneWidget);
  });
}
