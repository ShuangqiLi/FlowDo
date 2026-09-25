import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/api/api_client.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/screens/task_list_screen.dart';
import 'package:flowdo/theme.dart';
import 'package:flowdo/widgets/priority_selector.dart';

class _FakeApi extends ApiClient {
  _FakeApi(super.prefs, {this.failUpdate = false});

  final bool failUpdate;
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
  Future<Task> updateTask(
    String id, {
    String? title,
    String? body,
    String? priority,
    String? status,
  }) async {
    if (failUpdate) {
      throw ApiException('手头这 3 件先盯紧啦。');
    }
    final i = tasks.indexWhere((t) => t.id == id);
    final old = tasks[i];
    final moved = Task(
      id: old.id,
      title: old.title,
      status: status ?? old.status,
      priority: priority ?? old.priority,
      createdAt: old.createdAt,
      updatedAt: old.updatedAt,
    );
    tasks[i] = moved;
    return moved;
  }
}

Future<void> _pumpInbox(
  WidgetTester tester,
  _FakeApi api, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
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
        apiProvider.overrideWithValue(api),
        meProvider.overrideWith((_) async => me),
      ],
      child: MaterialApp(
        theme: buildAppTheme().copyWith(platform: platform),
        home: const Scaffold(body: TaskListScreen(status: 'TODO')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _swipeRight(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  for (var i = 0; i < 20; i++) {
    await gesture.moveBy(const Offset(35, 0));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'accessToken': 'token'}));

  testWidgets('swiping a task away removes its Slidable from the tree', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeApi(prefs);
    await _pumpInbox(tester, api);
    expect(find.text('喂猫'), findsOneWidget);
    expect(find.byTooltip('聚焦'), findsNothing);
    expect(find.byTooltip('不做了'), findsNothing);

    await _swipeRight(tester, find.text('喂猫'));

    expect(tester.takeException(), isNull);
    expect(find.text('喂猫'), findsNothing);
    expect(api.tasks.single.status, 'FOCUS');
  });

  testWidgets('a rejected swipe brings the task back without a Slidable error', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeApi(prefs, failUpdate: true);
    await _pumpInbox(tester, api);

    await _swipeRight(tester, find.text('喂猫'));

    expect(tester.takeException(), isNull);
    expect(find.text('喂猫'), findsOneWidget);
    expect(api.tasks.single.status, 'TODO');
  });

  testWidgets('desktop and web show action buttons and ignore a swipe', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeApi(prefs);
    await _pumpInbox(tester, api, platform: TargetPlatform.windows);

    expect(find.byTooltip('聚焦'), findsOneWidget);
    expect(find.byTooltip('不做了'), findsOneWidget);

    await _swipeRight(tester, find.text('喂猫'));

    expect(tester.takeException(), isNull);
    expect(find.text('喂猫'), findsOneWidget);
    expect(api.tasks.single.status, 'TODO');

    await tester.tap(find.byTooltip('聚焦'));
    await tester.pumpAndSettle();
    expect(api.tasks.single.status, 'FOCUS');
    expect(find.text('喂猫'), findsNothing);
  });

  testWidgets('the priority picker opens next to the badge, not over the screen', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeApi(prefs);
    await _pumpInbox(tester, api);

    final badge = find.byType(PriorityBadge);
    final badgeRect = tester.getRect(badge);

    await tester.tap(badge);
    await tester.pumpAndSettle();

    final items = find.byType(PopupMenuItem<String>);
    expect(items, findsNWidgets(3));
    for (final label in ['高', '中', '低']) {
      expect(find.descendant(of: items, matching: find.text(label)), findsOneWidget);
    }

    final menuRect = tester.getRect(items.first);
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(menuRect.width, lessThan(screen.width / 2));
    expect(menuRect.top, greaterThanOrEqualTo(badgeRect.top));
    expect((menuRect.left - badgeRect.left).abs(), lessThan(48));

    await tester.tap(find.descendant(of: items, matching: find.text('低')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(api.tasks.single.priority, 'LOW');
  });
}
