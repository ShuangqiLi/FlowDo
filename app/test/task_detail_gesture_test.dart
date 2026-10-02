import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/space.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/screens/task_detail_screen.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/ui/swipe_away.dart';
import 'provider_overrides.dart';

void main() {
  testWidgets('dragging across the note selects instead of swiping the page', (tester) async {
    await _pumpDetail(tester);
    final title = find.text('随手记');
    final before = tester.getTopLeft(title);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(TextField).last));
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();

    expect((tester.getTopLeft(title).dx - before.dx).abs(), lessThan(8));
    await gesture.up();
  });

  testWidgets('dragging the blank title bar still swipes the note closed', (tester) async {
    await _pumpDetail(tester);
    final title = find.text('随手记');
    final before = tester.getTopLeft(title);

    final gesture = await tester.startGesture(tester.getCenter(title));
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();

    expect(tester.getTopLeft(title).dx, greaterThan(before.dx + 40));
    await gesture.up();
  });
}

Future<void> _pumpDetail(WidgetTester tester) async {
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
            task: Task(
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
