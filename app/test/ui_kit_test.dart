import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr/models/task.dart';
import 'package:taskmgr/theme.dart';
import 'package:taskmgr/ui/celebration_overlay.dart';
import 'package:taskmgr/ui/flowdo_logo.dart';
import 'package:taskmgr/ui/task_card.dart';

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
    expect(find.byIcon(Icons.keyboard_double_arrow_up_rounded), findsOneWidget);
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
