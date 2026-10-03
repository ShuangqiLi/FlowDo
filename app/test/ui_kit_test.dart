import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/ui/celebration_overlay.dart';
import 'package:flowdo/ui/flowdo_logo.dart';
import 'package:flowdo/ui/task_card.dart';

void main() {
  testWidgets('logo and task card use reusable UI kit', (tester) async {
    var opened = false;
    final now = DateTime(2026, 9, 25);
    final task = Task(
      id: '1',
      title: '给窗边的绿植浇水',
      status: 'TODO',
      priority: 'HIGH',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const FlowDoLogo(),
              TaskCard(
                task: task,
                onOpen: () => opened = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('FlowDo'), findsOneWidget);
    expect(find.text('高'), findsOneWidget);
    await tester.tap(find.text('给窗边的绿植浇水'));
    expect(opened, isTrue);
  });

  testWidgets('each priority card uses a different wash', (tester) async {
    final now = DateTime(2026, 9, 25);
    const keys = [
      'HIGH',
      'MEDIUM',
      'LOW',
      'NONE',
      'REMINDER',
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Column(
            children: [
              for (final priority in keys)
                TaskCard(
                  key: ValueKey('$priority-card'),
                  task: Task(
                    id: priority,
                    title: priority,
                    status: 'TODO',
                    priority: priority,
                    createdAt: now,
                    updatedAt: now,
                  ),
                  onOpen: () {},
                ),
            ],
          ),
        ),
      ),
    );

    Color firstOf(String priority) {
      final ink = tester.widget<Ink>(
        find
            .descendant(
              of: find.byKey(ValueKey('$priority-card')),
              matching: find.byType(Ink),
            )
            .first,
      );
      return ((ink.decoration as BoxDecoration).gradient as LinearGradient)
          .colors
          .first;
    }

    final washes = [for (final priority in keys) firstOf(priority)];
    expect(washes.toSet(), hasLength(keys.length));
    expect(
      tester
          .widget<Ink>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('NONE-card')),
                  matching: find.byType(Ink),
                )
                .first,
          )
          .decoration,
      isA<BoxDecoration>()
          .having((d) => d.gradient, 'gradient', isA<LinearGradient>()),
    );
  });

  testWidgets('completion celebration removes itself', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeKey.lightPurple),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    showFlowDoCelebration(context);
    await tester.pump();
    expect(find.byKey(const ValueKey('flowdo-celebration')), findsOneWidget);
    await tester.pump(AppMotion.celebration + const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowdo-celebration')), findsNothing);
  });
}
