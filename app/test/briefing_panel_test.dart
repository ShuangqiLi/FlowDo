import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/models/briefing.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/screens/briefing_screen.dart';
import 'package:flowdo/screens/home_screen.dart';
import 'package:flowdo/theme.dart';

Briefing _briefing() {
  final now = DateTime(2026, 9, 25);
  return Briefing(
    date: '2026年9月25日',
    todoCount: 1,
    focusCount: 0,
    doneCount: 0,
    archivedCount: 0,
    focusedTasks: const [],
    suggestedFocus: [
      Task(
        id: '1',
        title: '喂猫',
        status: 'TODO',
        priority: 'HIGH',
        createdAt: now,
        updatedAt: now,
      ),
    ],
    completedToday: const [],
    completedYesterday: const [],
    completedThisWeek: const [],
    pendingArchive: 0,
  );
}

Future<void> _pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'accessToken': 'token',
    'lastBriefingDate': DateTime.now().toIso8601String().substring(0, 10),
  });
  final prefs = await SharedPreferences.getInstance();
  final me = Me(
    id: 'user',
    email: 'hello@flowdo.test',
    archiveAfterDays: 7,
    focusLimit: 3,
    deleteArchivedAfterDays: 30,
    showArchiveTab: true,
    themeKey: 'mint',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        meProvider.overrideWith((_) async => me),
        briefingProvider.overrideWith((_) async => _briefing()),
        tasksProvider.overrideWith((_, __) async => <Task>[]),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _toggle() => find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(IconButton),
    );

bool _panelVisible() => find.text('可以先做这些').evaluate().isNotEmpty;

bool _toggleSaysOpen() => find.byIcon(Icons.close).evaluate().isNotEmpty;

Future<void> _openBriefing(WidgetTester tester) async {
  if (!_panelVisible()) {
    await tester.tap(_toggle().first);
    await tester.pumpAndSettle();
  }
}

Future<void> _swipeAway(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text('可以先做这些').first));
  for (var i = 0; i < 20; i++) {
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
  }
  await gesture.up();
}

void main() {
  testWidgets('swiping the briefing away closes it right away', (tester) async {
    await _pumpHome(tester);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('任务池')),
      findsNothing,
    );
    await _openBriefing(tester);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('今日看看')),
      findsOneWidget,
    );
    expect(_panelVisible(), isTrue);

    await _swipeAway(tester);
    await tester.pump();
    expect(_toggleSaysOpen(), isFalse);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_panelVisible(), isFalse);

    await _openBriefing(tester);
    expect(_panelVisible(), isTrue);
  });

  testWidgets('a short drag snaps the briefing back instead of closing', (tester) async {
    await _pumpHome(tester);
    await _openBriefing(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.text('可以先做这些').first));
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_panelVisible(), isTrue);
    expect(_toggleSaysOpen(), isTrue);
  });

  for (final seed in [1, 2, 3, 4]) {
    testWidgets('toggle and panel never disagree, seed $seed', (tester) async {
      await _pumpHome(tester);
      final rng = math.Random(seed);
      final log = <String>[];

      for (var step = 0; step < 25; step++) {
        if (rng.nextBool() && _panelVisible()) {
          log.add('swipe');
          await _swipeAway(tester);
        } else {
          log.add('tap');
          await tester.tap(_toggle().first);
        }
        await tester.pump(Duration(milliseconds: rng.nextInt(500)));

        expect(tester.takeException(), isNull, reason: 'step $step: ${log.join(",")}');
        if (_toggleSaysOpen()) {
          final panel = find.byType(BriefingScreen);
          expect(
            panel,
            findsWidgets,
            reason: 'toggle says open but the panel is gone at step $step: ${log.join(",")}',
          );
          expect(
            tester.getSize(panel.first).height,
            greaterThan(0),
            reason: 'toggle says open but the panel collapsed at step $step: ${log.join(",")}',
          );
        }
      }

      await tester.pumpAndSettle();
      await _openBriefing(tester);
      expect(tester.takeException(), isNull);
      expect(_panelVisible(), isTrue, reason: 'stuck after ${log.join(",")}');
    });
  }
}
