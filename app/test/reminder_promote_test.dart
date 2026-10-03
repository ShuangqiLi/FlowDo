import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/api/api_client.dart';
import 'package:flowdo/models/notice.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'provider_overrides.dart';

class _ReminderApi extends ApiClient {
  _ReminderApi(super.prefs);

  final List<Task> tasks = [];
  final List<Notice> notices = [];

  @override
  Future<List<Task>> listTasks({String? status}) async =>
      tasks.where((task) => task.status == status).toList();

  @override
  Future<List<Notice>> listNotices() async => List<Notice>.of(notices);
}

Task _task({
  required String id,
  required String status,
  String repeat = 'ONCE',
  DateTime? remindAt,
}) {
  return Task(
    id: id,
    title: '浇花',
    status: status,
    priority: 'REMINDER',
    remindAt: remindAt,
    remindRepeat: repeat,
    createdAt: DateTime(2026, 10, 3, 21),
    updatedAt: DateTime(2026, 10, 3, 21),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ReminderApi api;
  late ProviderContainer container;
  late List<ProviderSubscription<dynamic>> subs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = _ReminderApi(prefs);
    container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        meOverride(
          Me(
            id: 'user',
            activeSpaceId: 'space',
            archiveAfterDays: 7,
            focusLimit: 3,
            deleteArchivedAfterDays: 30,
            showArchiveTab: false,
            themeKey: 'mint',
          ),
        ),
      ],
    );
    subs = [
      container.listen(tasksProvider('TODO'), (_, __) {}),
      container.listen(tasksProvider('FOCUS'), (_, __) {}),
      container.listen(noticesProvider, (_, __) {}),
    ];
  });

  tearDown(() {
    for (final sub in subs) {
      sub.close();
    }
    container.dispose();
  });

  Future<void> loadLists() async {
    container.invalidate(tasksProvider('TODO'));
    container.invalidate(tasksProvider('FOCUS'));
    container.invalidate(noticesProvider);
    await container.read(tasksProvider('TODO').future);
    await container.read(tasksProvider('FOCUS').future);
    await container.read(noticesProvider.future);
  }

  test('a due one-time reminder leaves the pool before the server moves it',
      () async {
    final due = DateTime.now().subtract(const Duration(minutes: 1));
    api.tasks.add(_task(id: 'once', status: 'TODO', remindAt: due));
    await loadLists();

    await container.read(noticesProvider.notifier).refresh();

    expect(container.read(tasksProvider('TODO')).value, isEmpty);
    expect(
      container.read(tasksProvider('FOCUS')).value!.map((task) => task.id),
      ['once'],
    );

    await container.read(noticesProvider.notifier).refresh();

    expect(container.read(tasksProvider('TODO')).value, isEmpty);
    expect(
      container.read(tasksProvider('FOCUS')).value!.single.status,
      'FOCUS',
    );
  });

  test('once the server has moved it, the pool does not grow a second copy',
      () async {
    final due = DateTime.now().subtract(const Duration(minutes: 1));
    api.tasks.add(_task(id: 'once', status: 'TODO', remindAt: due));
    await loadLists();

    api.tasks
      ..clear()
      ..add(_task(id: 'once', status: 'FOCUS', remindAt: due));
    api.notices.add(
      Notice(
        id: 'n1',
        taskId: 'once',
        title: '浇花',
        message: '到点了，已经放进聚焦',
        createdAt: DateTime.now(),
      ),
    );

    await container.read(noticesProvider.notifier).refresh();

    expect(container.read(tasksProvider('TODO')).value, isEmpty);
    expect(container.read(tasksProvider('FOCUS')).value, hasLength(1));
    expect(
      container.read(tasksProvider('FOCUS')).value!.single.id,
      'once',
    );
  });

  test('a repeating reminder stays in the pool when its copy enters focus',
      () async {
    final due = DateTime.now().subtract(const Duration(minutes: 1));
    api.tasks.add(
      _task(id: 'series', status: 'TODO', repeat: 'DAILY', remindAt: due),
    );
    await loadLists();

    api.tasks
      ..clear()
      ..add(
        _task(
          id: 'series',
          status: 'TODO',
          repeat: 'DAILY',
          remindAt: due.add(const Duration(days: 1)),
        ),
      )
      ..add(_task(id: 'clone', status: 'FOCUS', remindAt: due));
    api.notices.add(
      Notice(
        id: 'n2',
        taskId: 'clone',
        title: '浇花',
        message: '到点了，已经放进聚焦',
        createdAt: DateTime.now(),
      ),
    );

    await container.read(noticesProvider.notifier).refresh();

    expect(
      container.read(tasksProvider('TODO')).value!.single.remindAt,
      due.add(const Duration(days: 1)),
    );
    expect(
      container.read(tasksProvider('FOCUS')).value!.map((task) => task.id),
      ['clone'],
    );
  });
}
