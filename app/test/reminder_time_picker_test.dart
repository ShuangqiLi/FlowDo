import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/theme.dart';
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
}
