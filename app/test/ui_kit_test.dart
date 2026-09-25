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
                actions: const [],
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
