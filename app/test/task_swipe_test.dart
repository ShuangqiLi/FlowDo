import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmgr/api/api_client.dart';
import 'package:taskmgr/models/task.dart';
import 'package:taskmgr/models/user.dart';
import 'package:taskmgr/providers.dart';
import 'package:taskmgr/screens/task_list_screen.dart';
import 'package:taskmgr/theme.dart';

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

Future<void> _pumpInbox(WidgetTester tester, _FakeApi api) async {
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
        theme: buildAppTheme(),
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
}
