import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/briefing.dart';
import 'package:flowdo/models/space.dart';
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

  test('briefing json reads per-space totals', () {
    final briefing = Briefing.fromJson({
      'date': '2026-10-03',
      'counts': {
        'todo': 10,
        'focus': 2,
        'done': 5,
        'archived': 1,
        'reminders': 3,
        'total': 18,
      },
      'spaces': [
        {
          'id': 'work',
          'name': '工作',
          'themeKey': 'hazeBlue',
          'todo': 4,
          'focus': 1,
          'done': 2,
          'archived': 0,
          'reminders': 2,
          'completedToday': 1,
          'completedYesterday': 0,
        },
      ],
      'focusedTasks': [],
      'suggestedFocus': [],
      'completedToday': [],
      'completedYesterday': [],
      'pendingArchive': 5,
    });
    expect(briefing.totalCount, 18);
    expect(briefing.reminderCount, 3);
    expect(briefing.spaces.single.name, '工作');
    expect(briefing.spaces.single.total, 7);
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

  testWidgets('a future reminder shows flags instead of a clock time',
      (tester) async {
    final when = DateTime.now().add(const Duration(days: 40, hours: 9));
    final key =
        '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: when.year,
            month: when.month,
            days: [
              ReviewDay(
                date: key,
                count: 5,
                reminders: [
                  Task(
                    id: 'r1',
                    title: '去邮局',
                    status: 'TODO',
                    priority: 'REMINDER',
                    remindAt: when,
                    createdAt: when,
                    updatedAt: when,
                  ),
                  Task(
                    id: 'r2',
                    title: '回电',
                    status: 'TODO',
                    priority: 'REMINDER',
                    remindAt: when.add(const Duration(hours: 2)),
                    createdAt: when,
                    updatedAt: when,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('09:30'), findsNothing);
    expect(find.byIcon(Icons.flag_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsNWidgets(2));
    expect(tester.getSemantics(find.text('${when.day}')).label,
        contains('提醒 2 件'));
    expect(tester.getSemantics(find.text('${when.day}')).label,
        contains('完成 5 件'));
  });

  testWidgets('nine completed tasks collapse to one crown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: 2026,
            month: 12,
            days: [
              ReviewDay(date: '2026-12-15', count: 12),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.circle), findsNothing);
  });

  testWidgets('more than three reminders show three flags and a plus',
      (tester) async {
    final when = DateTime.now().add(const Duration(days: 20));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: when.year,
            month: when.month,
            days: [
              ReviewDay(
                date:
                    '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}',
                count: 0,
                reminders: [
                  for (var i = 0; i < 5; i++)
                    Task(
                      id: 'r$i',
                      title: '提醒$i',
                      status: 'TODO',
                      priority: 'REMINDER',
                      remindAt: when.add(Duration(hours: i)),
                      createdAt: when,
                      updatedAt: when,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.flag_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('two spaces keep separate completion tallies', (tester) async {
    final now = DateTime(2026, 12, 15);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: 2026,
            month: 12,
            spaces: [
              Space(id: 'work', name: '工作', themeKey: 'hazeBlue'),
              Space(id: 'life', name: '生活', themeKey: 'mint'),
            ],
            days: [
              ReviewDay(
                date: '2026-12-15',
                count: 10,
                tasks: [
                  for (var i = 0; i < 5; i++)
                    Task(
                      id: 'w$i',
                      title: '工作$i',
                      status: 'DONE',
                      priority: 'MEDIUM',
                      spaceId: 'work',
                      createdAt: now,
                      updatedAt: now,
                      completedAt: now,
                    ),
                  for (var i = 0; i < 5; i++)
                    Task(
                      id: 'l$i',
                      title: '生活$i',
                      status: 'DONE',
                      priority: 'MEDIUM',
                      spaceId: 'life',
                      createdAt: now,
                      updatedAt: now,
                      completedAt: now,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.circle), findsNWidgets(4));
  });
}
