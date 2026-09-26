import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/api/api_client.dart';
import 'package:flowdo/models/briefing.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/screens/home_screen.dart';
import 'package:flowdo/theme.dart';

class _FakeApi extends ApiClient {
  _FakeApi(super.prefs);

  final List<Task> tasks = [
    Task(
      id: '1',
      title: '喂猫',
      status: 'TODO',
      priority: 'MEDIUM',
      createdAt: DateTime(2026, 9, 25),
      updatedAt: DateTime(2026, 9, 25),
    ),
  ];

  @override
  Future<List<Task>> listTasks({String? status}) async =>
      tasks.where((t) => t.status == status).toList();

  @override
  Future<Task> createTask({
    required String title,
    String? body,
    String? priority,
  }) async {
    final task = Task(
      id: '${tasks.length + 1}',
      title: title,
      status: 'TODO',
      priority: priority ?? 'MEDIUM',
      createdAt: DateTime(2026, 9, 25),
      updatedAt: DateTime(2026, 9, 25),
    );
    tasks.add(task);
    return task;
  }

  @override
  Future<Briefing> todayBriefing() async {
    return Briefing(
      date: '2026年9月25日',
      todoCount: tasks.where((t) => t.status == 'TODO').length,
      focusCount: 0,
      doneCount: 0,
      archivedCount: 0,
      focusedTasks: const [],
      suggestedFocus: const [],
      completedToday: const [],
      completedYesterday: const [],
      pendingArchive: 0,
    );
  }
}

Future<_FakeApi> _pumpHome(
  WidgetTester tester, {
  bool voiceInputEnabled = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'accessToken': 'token',
    'lastBriefingDate': DateTime.now().toIso8601String().substring(0, 10),
  });
  final prefs = await SharedPreferences.getInstance();
  final api = _FakeApi(prefs);
  final me = Me(
    id: 'user',
    username: 'hello',
    archiveAfterDays: 7,
    focusLimit: 3,
    deleteArchivedAfterDays: 30,
    showArchiveTab: true,
    themeKey: 'mint',
    voiceInputEnabled: voiceInputEnabled,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        apiProvider.overrideWithValue(api),
        meProvider.overrideWith((_) async => me),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('FAB is the add entry and creates a pool task', (tester) async {
    final api = await _pumpHome(tester);
    expect(find.text('想到什么？先放进任务池'), findsNothing);

    await tester.tap(find.text('聚焦'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();
    expect(find.text('想到什么？先放进任务池'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '买菜');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('想到什么？先放进任务池'), findsNothing);
    expect(api.tasks.map((t) => t.title), contains('买菜'));
    expect(find.text('买菜'), findsOneWidget);
    expect(find.textContaining('任务池空空的'), findsNothing);
  });

  testWidgets('FAB snaps to an edge and remembers the side for the account', (tester) async {
    await _pumpHome(tester);
    final fab = find.byKey(const ValueKey('add-task-fab'));
    final start = tester.getCenter(fab);
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(Offset(24, start.dy - 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fabPos:user'), startsWith('left:'));
    expect(
      tester.getCenter(fab).dx,
      lessThan(tester.getSize(find.byType(MaterialApp)).width / 2),
    );
  });

  testWidgets('holding the FAB without speech support falls back to typing',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await _pumpHome(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('add-task-fab'))),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('还不能语音输入'), findsOneWidget);
      expect(find.text('正在听，松开就好'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('想到什么？先放进任务池'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('holding the FAB with voice switched off in the account falls back to typing',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pumpHome(tester, voiceInputEnabled: false);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('add-task-fab'))),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('设置里关着'), findsOneWidget);
      expect(find.text('正在听，松开就好'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('想到什么？先放进任务池'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('dock is flat, evenly split, with focus in the middle and largest',
      (tester) async {
    await _pumpHome(tester);
    final bodyBottom = tester.getRect(find.byType(PageView)).bottom;
    final screen = tester.getSize(find.byType(MaterialApp));

    final rects = {
      for (final label in ['任务池', '聚焦', '完成'])
        label: tester.getRect(find.byTooltip(label)),
    };
    for (final entry in rects.entries) {
      expect(entry.value.top, greaterThanOrEqualTo(bodyBottom), reason: entry.key);
      expect(entry.value.bottom, lessThanOrEqualTo(screen.height), reason: entry.key);
      expect(entry.value.height, greaterThanOrEqualTo(48), reason: entry.key);
      expect(entry.value.width, greaterThanOrEqualTo(48), reason: entry.key);
    }

    // 三等分：三个页签一样宽，聚焦正好在屏幕中线上。
    expect(rects['任务池']!.width, moreOrLessEquals(rects['聚焦']!.width, epsilon: 1));
    expect(rects['完成']!.width, moreOrLessEquals(rects['聚焦']!.width, epsilon: 1));
    expect(rects['聚焦']!.center.dx, moreOrLessEquals(screen.width / 2, epsilon: 1));
    expect(rects['任务池']!.right, lessThanOrEqualTo(rects['聚焦']!.left + 1));
    expect(rects['聚焦']!.right, lessThanOrEqualTo(rects['完成']!.left + 1));

    // 聚焦的图标比两边大。
    final focusIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('聚焦'),
        matching: find.byIcon(Icons.center_focus_strong_rounded),
      ),
    );
    final poolIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('任务池'),
        matching: find.byType(Icon),
      ),
    );
    expect(focusIcon.size!, greaterThan(poolIcon.size!));

    // 选中态只落在图标上：任何装饰盒都不能盖到文字（旧版是图标加文字一起套边框）。
    await tester.tap(find.byTooltip('任务池'));
    await tester.pumpAndSettle();
    final poolLabel = tester.getRect(
      find.descendant(of: find.byTooltip('任务池'), matching: find.text('任务池')),
    );
    final boxes = find
        .descendant(of: find.byTooltip('任务池'), matching: find.byType(DecoratedBox))
        .evaluate();
    expect(boxes, isNotEmpty);
    for (final box in boxes) {
      final rect = tester.getRect(find.byWidget(box.widget));
      expect(rect.overlaps(poolLabel), isFalse, reason: 'indicator must not frame the label');
    }
  });

  testWidgets('settings and archive open from top-left app bar', (tester) async {
    await _pumpHome(tester);
    expect(find.text('聚焦'), findsOneWidget);
    expect(find.text('任务池'), findsWidgets);
    expect(find.text('完成'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-archive')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('任务池')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('open-archive')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('归档')),
      findsOneWidget,
    );
    expect(find.textContaining('归档柜空着'), findsOneWidget);
    final archiveSwipe = await tester.startGesture(
      tester.getCenter(find.textContaining('归档柜空着')),
    );
    for (var i = 0; i < 20; i++) {
      await archiveSwipe.moveBy(const Offset(40, 0));
      await tester.pump();
    }
    await archiveSwipe.up();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('归档')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('设置')),
      findsOneWidget,
    );
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('打开归档柜'), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.text('账号')));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('账号'), findsNothing);
    expect(find.byKey(const ValueKey('open-settings')), findsOneWidget);
  });
}
