import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:flowdo/models/space.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/screens/task_detail_screen.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/ui/swipe_away.dart';
import 'provider_overrides.dart';

void main() {
  testWidgets('dragging across the note selects instead of swiping the page',
      (tester) async {
    await _pumpDetail(tester);
    final title = find.text('任务详情');
    final before = tester.getTopLeft(title);

    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(TextField).last));
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();

    expect((tester.getTopLeft(title).dx - before.dx).abs(), lessThan(8));
    await gesture.up();
  });

  testWidgets('dragging the blank title bar still swipes the note closed',
      (tester) async {
    await _pumpDetail(tester);
    final title = find.text('任务详情');
    final before = tester.getTopLeft(title);

    final gesture = await tester.startGesture(tester.getCenter(title));
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();

    expect(tester.getTopLeft(title).dx, greaterThan(before.dx + 40));
    await gesture.up();
  });

  testWidgets('a reminder task shows when it rings and how often',
      (tester) async {
    final when = DateTime.now().add(const Duration(days: 2, hours: 3));
    await _pumpDetail(
      tester,
      task: Task(
        id: 'r1',
        title: '交房租',
        status: 'TODO',
        priority: 'REMINDER',
        remindAt: when,
        remindRepeat: 'MONTHLY',
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      ),
    );

    expect(
      find.text(DateFormat('yyyy年M月d日 HH:mm').format(when)),
      findsOneWidget,
    );
    expect(find.textContaining('每月'), findsOneWidget);
    expect(find.textContaining('还有 2 天'), findsOneWidget);
    expect(find.text('改时间'), findsOneWidget);
    expect(find.text('过程小记'), findsNothing);
    expect(
      tester.getTopLeft(find.text('在任务池')).dy,
      lessThan(tester.getTopLeft(find.text('交房租')).dy),
    );
  });

  testWidgets('ordinary tasks keep notes under the status row', (tester) async {
    await _pumpDetail(tester);
    expect(find.text('过程小记'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('在任务池')).dy,
      lessThan(tester.getTopLeft(find.text('写方案')).dy),
    );
  });
}

Future<void> _pumpDetail(WidgetTester tester, {Task? task}) async {
  final now = DateTime(2026, 9, 25);
  final me = Me(
    id: 'user',
    activeSpaceId: 'space',
    archiveAfterDays: 7,
    focusLimit: 3,
    deleteArchivedAfterDays: 30,
    showArchiveTab: true,
    themeKey: 'mint',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meOverride(me),
        spacesOverride([Space(id: 'space', name: '默认')]),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: SwipeToPop(
          fromLeftEdgeOnly: false,
          child: TaskDetailScreen(
            task: task ??
                Task(
                  id: '1',
                  title: '写方案',
                  body: '今天把方案写完，还要再改一稿，别忘了核对数字。',
                  status: 'TODO',
                  priority: 'MEDIUM',
                  createdAt: now,
                  updatedAt: now,
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
