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
    expect(find.text('八月十五'), findsOneWidget);
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

  test('briefing json reads reminder counts for the current space', () {
    final briefing = Briefing.fromJson({
      'date': '2026-10-03',
      'counts': {
        'todo': 10,
        'focus': 2,
        'done': 5,
        'archived': 1,
        'reminders': 3,
      },
      'focusedTasks': [],
      'suggestedFocus': [],
      'completedToday': [],
      'completedYesterday': [],
      'pendingArchive': 5,
    });
    expect(briefing.reminderCount, 3);
    expect(briefing.todoCount, 10);
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

  testWidgets('an empty day menu stops after the short summary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: 2026,
            month: 9,
            days: const [],
            todayKey: '2026-09-24',
            onDayTap: (anchor, day) {
              showReviewDayPopover(
                anchor,
                day: day,
                todayKey: '2026-09-24',
                onOpenTask: (_) {},
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('这一天没有完成的事'), findsOneWidget);
    expect(find.textContaining('也挺好'), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    expect(find.text('这一天还没有提醒'), findsOneWidget);
    expect(find.textContaining('安排提醒'), findsNothing);
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

  testWidgets('today shows reminders above completions', (tester) async {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final later = now.add(const Duration(hours: 2));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MonthReviewCalendar(
            year: now.year,
            month: now.month,
            todayKey: key,
            days: [
              ReviewDay(
                date: key,
                count: 3,
                tasks: [
                  Task(
                    id: 'd1',
                    title: '做完了',
                    status: 'DONE',
                    priority: 'MEDIUM',
                    createdAt: now,
                    updatedAt: now,
                    completedAt: now,
                  ),
                  Task(
                    id: 'd2',
                    title: '也做完了',
                    status: 'DONE',
                    priority: 'LOW',
                    createdAt: now,
                    updatedAt: now,
                    completedAt: now,
                  ),
                  Task(
                    id: 'd3',
                    title: '第三件',
                    status: 'DONE',
                    priority: 'LOW',
                    createdAt: now,
                    updatedAt: now,
                    completedAt: now,
                  ),
                ],
                reminders: [
                  Task(
                    id: 'r1',
                    title: '晚上提醒',
                    status: 'TODO',
                    priority: 'REMINDER',
                    remindAt: later,
                    createdAt: now,
                    updatedAt: now,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(
      tester.getTopLeft(find.byIcon(Icons.flag_rounded)).dy,
      lessThan(tester.getTopLeft(find.byIcon(Icons.star_rounded)).dy),
    );
  });

  test('past days keep completions and drop reminders', () {
    final when = DateTime(2026, 10, 10, 9);
    final tally = tallyForReviewDay(
      ReviewDay(
        date: '2026-10-01',
        count: 4,
        reminders: [
          Task(
            id: 'r',
            title: '过期提醒',
            status: 'TODO',
            priority: 'REMINDER',
            remindAt: DateTime.now().add(const Duration(days: 2)),
            createdAt: when,
            updatedAt: when,
          ),
        ],
      ),
      todayKey: '2026-10-03',
    );
    expect(tally.reminderCount, 0);
    expect(tally.completedCount, 4);
  });

  test('today keeps both reminders and completions', () {
    final later = DateTime.now().add(const Duration(hours: 3));
    final tally = tallyForReviewDay(
      ReviewDay(
        date: '2026-10-03',
        count: 2,
        reminders: [
          Task(
            id: 'r',
            title: '今晚',
            status: 'TODO',
            priority: 'REMINDER',
            remindAt: later,
            createdAt: later,
            updatedAt: later,
          ),
        ],
      ),
      todayKey: '2026-10-03',
    );
    expect(tally.reminderCount, 1);
    expect(tally.completedCount, 2);
  });

  test('future days keep reminders and drop completions', () {
    final when = DateTime.now().add(const Duration(days: 8));
    final key =
        '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
    final tally = tallyForReviewDay(
      ReviewDay(
        date: key,
        count: 9,
        reminders: [
          Task(
            id: 'r',
            title: '以后提醒',
            status: 'TODO',
            priority: 'REMINDER',
            remindAt: when,
            createdAt: when,
            updatedAt: when,
          ),
        ],
      ),
      todayKey: '2026-10-03',
    );
    expect(tally.reminderCount, 1);
    expect(tally.completedCount, 0);
  });
}
