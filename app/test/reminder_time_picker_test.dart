import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/utils/lunar.dart';
import 'package:flowdo/widgets/reminder_time_picker.dart';

void main() {
  testWidgets('reminder picker uses a Chinese Monday calendar and steppers',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    ReminderPlan? plan;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  plan = await showReminderTimePicker(
                    context,
                    initial:
                        DateTime.now().add(const Duration(days: 5, hours: 2)),
                  );
                },
                child: const Text('设提醒'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('设提醒'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reminder-calendar')), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(CupertinoPicker), findsNothing);
    expect(find.byType(ListWheelScrollView), findsNothing);
    expect(find.text('时'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);

    final calendar = find.byKey(const ValueKey('reminder-calendar'));
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final xs = [
      for (final label in labels)
        tester
            .getTopLeft(
              find.descendant(of: calendar, matching: find.text(label)),
            )
            .dx,
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]));
    }

    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();
    expect(plan, isNotNull);
    expect(plan!.repeat, 'ONCE');
  });

  testWidgets('hour field rejects numbers outside 0-23', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showReminderTimePicker(
                  context,
                  initial: DateTime.now().add(const Duration(days: 1)),
                ),
                child: const Text('设提醒'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('设提醒'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reminder-hour-field')),
      '25',
    );
    await tester.tap(find.text('好'));
    await tester.pump();
    expect(find.text('小时是 0 到 23'), findsOneWidget);
    expect(find.text('设个提醒'), findsOneWidget);
  });

  testWidgets('crontab repeat hides the calendar and keeps the expression',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    ReminderPlan? plan;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  plan = await showReminderTimePicker(context);
                },
                child: const Text('设提醒'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('设提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('crontab'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reminder-calendar')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('reminder-cron-field')),
      '0 9 * * 1-5',
    );
    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();
    expect(plan, isNotNull);
    expect(plan!.repeat, 'CRON');
    expect(plan!.cron, '0 9 * * 1-5');
  });

  testWidgets('a utc reminder opens on the client local clock', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final instant = DateTime.utc(2027, 6, 15, 16, 30);
    final local = instant.toLocal();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showReminderTimePicker(
                  context,
                  initial: instant,
                ),
                child: const Text('设提醒'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('设提醒'));
    await tester.pumpAndSettle();

    String fieldText(String key) {
      final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
      return field.controller!.text;
    }

    expect(fieldText('reminder-hour-field'), local.hour.toString().padLeft(2, '0'));
    expect(
      fieldText('reminder-minute-field'),
      local.minute.toString().padLeft(2, '0'),
    );
  });

  test('once reminders show the time without a reminder prefix', () {
    final at = DateTime(2026, 10, 3, 22, 17);
    expect(reminderWhenText(at, lunar: false), '10月3日 22:17');
  });

  test('lunar reminders use the lunar date', () {
    final at = DateTime(2026, 10, 5);
    expect(
      reminderWhenText(at, lunar: true),
      '农历${lunarCellLabel(2026, 10, 5)} 00:00',
    );
  });
}
