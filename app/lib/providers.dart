import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'models/briefing.dart';
import 'models/notice.dart';
import 'models/space.dart';
import 'models/task.dart';
import 'models/user.dart';
import 'platform/microphone.dart';
import 'theme.dart';
import 'ui/focus_dock.dart';
import 'ui/task_sort.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefs must be overridden');
});

final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(prefsProvider));
});

final authStateProvider = NotifierProvider<AuthController, bool>(
  AuthController.new,
);

class AuthController extends Notifier<bool> {
  @override
  bool build() => ref.watch(apiProvider).isLoggedIn;

  Future<void> setup(String password) async {
    await ref.read(apiProvider).setupPassword(password);
    state = true;
  }

  Future<void> login(String password) async {
    await ref.read(apiProvider).login(password);
    state = true;
  }

  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    state = false;
  }
}

final meProvider = AsyncNotifierProvider<MeController, Me>(MeController.new);

class MeController extends AsyncNotifier<Me> {
  @override
  Future<Me> build() async {
    ref.watch(authStateProvider);
    return ref.read(apiProvider).getMe();
  }

  /// 用 PATCH /me 的返回值直接写回，省掉再 GET 一次。
  void apply(Me me) {
    state = AsyncData(me);
  }

  Future<Me> save({
    int? archiveAfterDays,
    int? focusLimit,
    int? deleteArchivedAfterDays,
    bool? showArchiveTab,
    bool? showRecurringReminders,
    String? themeKey,
    bool? voiceInputEnabled,
    String? activeSpaceId,
  }) async {
    final me = await ref.read(apiProvider).updateMe(
          archiveAfterDays: archiveAfterDays,
          focusLimit: focusLimit,
          deleteArchivedAfterDays: deleteArchivedAfterDays,
          showArchiveTab: showArchiveTab,
          showRecurringReminders: showRecurringReminders,
          themeKey: themeKey,
          voiceInputEnabled: voiceInputEnabled,
          activeSpaceId: activeSpaceId,
        );
    apply(me);
    return me;
  }

  Future<void> reload({bool quiet = false}) async {
    try {
      final me = await ref.read(apiProvider).getMe();
      state = AsyncData(me);
    } catch (error, stack) {
      if (!quiet || state.value == null) {
        state = AsyncError(error, stack);
      }
    }
  }
}

final tasksProvider =
    AsyncNotifierProvider.family<TasksController, List<Task>, String>(
  TasksController.new,
);

class TasksController extends AsyncNotifier<List<Task>> {
  TasksController(this.status);

  final String status;
  int _epoch = 0;

  @override
  Future<List<Task>> build() async {
    final epoch = ++_epoch;
    ref.watch(authStateProvider);
    final tasks = _merge(await ref.read(apiProvider).listTasks(status: status));
    if (epoch != _epoch) {
      return state.value ?? tasks;
    }
    _cacheCurrent(tasks);
    return tasks;
  }

  /// 丢掉还在路上的列表响应，避免慢请求盖掉刚写完的本地状态。
  void abandonInflight() {
    _epoch++;
  }

  Future<void> reload({bool quiet = false}) async {
    final epoch = ++_epoch;
    try {
      final tasks = _merge(await ref.read(apiProvider).listTasks(status: status));
      if (epoch != _epoch) {
        return;
      }
      state = AsyncData(tasks);
      _cacheCurrent(tasks);
    } catch (error, stack) {
      if (epoch != _epoch) {
        return;
      }
      if (!quiet || state.value == null) {
        state = AsyncError(error, stack);
      }
    }
  }

  /// 用刚拉到的服务端列表对账。未完成的本地改动仍盖在上面。
  void applyServer(List<Task> server) {
    final epoch = ++_epoch;
    final tasks = _merge(server);
    if (epoch != _epoch) {
      return;
    }
    state = AsyncData(tasks);
    _cacheCurrent(tasks);
  }

  List<Task> _merge(List<Task> tasks) {
    final spaceId = ref.read(meProvider).value?.activeSpaceId;
    return ref.read(pendingTaskWritesProvider).merge(status, spaceId, tasks);
  }

  void removeById(String id) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.where((task) => task.id != id).toList());
  }

  void upsert(Task task) {
    final current = List<Task>.of(state.value ?? const []);
    current.removeWhere((item) => item.id == task.id);
    current.add(task);
    current.sort((a, b) => compareTasksByPriorityThenRecent(a, b, status));
    state = AsyncData(current);
  }

  void replaceAll(List<Task> tasks) {
    state = AsyncData(List<Task>.of(tasks));
  }

  void _cacheCurrent(List<Task> tasks) {
    final spaceId = ref.read(meProvider).value?.activeSpaceId;
    if (spaceId == null) {
      return;
    }
    ref.read(spaceSnapshotCacheProvider).putTasks(spaceId, status, tasks);
  }
}

const taskListStatuses = ['TODO', 'FOCUS', 'DONE', 'ARCHIVED'];

/// 同一条任务的写请求排队发出。
/// 否则「进聚焦」还在路上时又「完成」，第二条先到服务端会被当成 TODO→DONE 拒掉。
final taskWriteQueueProvider = Provider<TaskWriteQueue>((ref) {
  return TaskWriteQueue();
});

class TaskWriteQueue {
  final Map<String, Future<void>> _tails = {};

  Future<T> run<T>(String id, Future<T> Function() job) {
    final previous = _tails[id] ?? Future<void>.value();
    final done = Completer<void>();
    _tails[id] = done.future;
    return previous.then((_) => job(), onError: (_) => job()).whenComplete(() {
      done.complete();
      if (identical(_tails[id], done.future)) {
        _tails.remove(id);
      }
    });
  }
}

/// 还没跟服务器对上的任务。刷新回来的旧列表不能把它们盖回去。
final pendingTaskWritesProvider = Provider<PendingTaskWrites>((ref) {
  return PendingTaskWrites();
});

class PendingTaskWrites {
  final Map<String, _TaskHold> _holds = {};

  /// [task] 为 null 表示这条已经从当前空间列表拿掉（删除或搬走）。
  int begin({
    required String id,
    required String? spaceId,
    required Task? task,
  }) {
    final next = (_holds[id]?.gen ?? 0) + 1;
    _holds[id] = _TaskHold(gen: next, spaceId: spaceId, task: task);
    return next;
  }

  void settle(String id, int gen) {
    final current = _holds[id];
    if (current == null || current.gen != gen) {
      return;
    }
    _holds.remove(id);
  }

  bool isPending(String id) => _holds.containsKey(id);

  List<Task> merge(String status, String? spaceId, List<Task> server) {
    if (_holds.isEmpty) {
      return server;
    }
    final result = <Task>[];
    final placed = <String>{};
    var changed = false;
    for (final task in server) {
      final hold = _holds[task.id];
      if (hold == null || hold.spaceId != spaceId) {
        result.add(task);
        continue;
      }
      changed = true;
      final override = hold.task;
      if (override != null && override.status == status) {
        result.add(override);
        placed.add(override.id);
      }
    }
    for (final entry in _holds.entries) {
      final hold = entry.value;
      final task = hold.task;
      if (hold.spaceId != spaceId || task == null || task.status != status) {
        continue;
      }
      if (placed.contains(task.id)) {
        continue;
      }
      changed = true;
      result.add(task);
    }
    if (!changed) {
      return server;
    }
    result.sort((a, b) => compareTasksByPriorityThenRecent(a, b, status));
    return result;
  }
}

class _TaskHold {
  const _TaskHold({
    required this.gen,
    required this.spaceId,
    required this.task,
  });

  final int gen;
  final String? spaceId;
  final Task? task;
}

/// 当前空间四个列表的内存快照，切回去时先亮出来再静默对账。
final spaceSnapshotCacheProvider = Provider<SpaceSnapshotCache>((ref) {
  return SpaceSnapshotCache();
});

class SpaceSnapshotCache {
  final Map<String, Map<String, List<Task>>> _tasks = {};
  final Map<String, Briefing> _briefings = {};

  void putTasks(String spaceId, String status, List<Task> tasks) {
    final bucket = _tasks.putIfAbsent(spaceId, () => {});
    bucket[status] = List<Task>.of(tasks);
  }

  void putBriefing(String spaceId, Briefing briefing) {
    _briefings[spaceId] = briefing;
  }

  Map<String, List<Task>>? tasksFor(String spaceId) => _tasks[spaceId];

  Briefing? briefingFor(String spaceId) => _briefings[spaceId];
}

/// 切空间：本地先换、有缓存先亮，网络在背后慢慢对。
Future<void> switchActiveSpace(WidgetRef ref, String spaceId) async {
  final me = ref.read(meProvider).value;
  if (me == null || me.activeSpaceId == spaceId) {
    return;
  }
  final previous = me;
  final fromId = previous.activeSpaceId;
  final cache = ref.read(spaceSnapshotCacheProvider);

  if (fromId != null) {
    for (final status in taskListStatuses) {
      final list = ref.read(tasksProvider(status)).value;
      if (list != null) {
        cache.putTasks(fromId, status, list);
      }
    }
    final briefing = ref.read(briefingProvider).value;
    if (briefing != null) {
      cache.putBriefing(fromId, briefing);
    }
  }

  ref.read(meProvider.notifier).apply(previous.copyWith(activeSpaceId: spaceId));

  final cachedTasks = cache.tasksFor(spaceId);
  if (cachedTasks != null) {
    for (final status in taskListStatuses) {
      final list = cachedTasks[status];
      if (list != null && ref.exists(tasksProvider(status))) {
        ref.read(tasksProvider(status).notifier).replaceAll(list);
      }
    }
  } else {
    for (final status in taskListStatuses) {
      if (ref.exists(tasksProvider(status))) {
        ref.read(tasksProvider(status).notifier).replaceAll(const []);
      }
    }
  }

  final cachedBriefing = cache.briefingFor(spaceId);
  if (cachedBriefing != null && ref.exists(briefingProvider)) {
    ref.read(briefingProvider.notifier).apply(cachedBriefing);
  }

  try {
    await ref.read(meProvider.notifier).save(activeSpaceId: spaceId);
    unawaited(
      ref
          .read(lazySyncProvider.notifier)
          .run(quiet: true, bumpCalendar: true)
          .then((_) {
        for (final status in taskListStatuses) {
          final list = ref.read(tasksProvider(status)).value;
          if (list != null) {
            cache.putTasks(spaceId, status, list);
          }
        }
        final briefing = ref.read(briefingProvider).value;
        if (briefing != null) {
          cache.putBriefing(spaceId, briefing);
        }
      }),
    );
  } catch (_) {
    ref.read(meProvider.notifier).apply(previous);
    if (fromId != null) {
      final rollback = cache.tasksFor(fromId);
      if (rollback != null) {
        for (final status in taskListStatuses) {
          final list = rollback[status];
          if (list != null && ref.exists(tasksProvider(status))) {
            ref.read(tasksProvider(status).notifier).replaceAll(list);
          }
        }
      }
      final briefing = cache.briefingFor(fromId);
      if (briefing != null && ref.exists(briefingProvider)) {
        ref.read(briefingProvider.notifier).apply(briefing);
      }
    }
    rethrow;
  }
}

final briefingProvider =
    AsyncNotifierProvider<BriefingController, Briefing>(BriefingController.new);

class BriefingController extends AsyncNotifier<Briefing> {
  @override
  Future<Briefing> build() async {
    ref.watch(authStateProvider);
    final briefing = await ref.read(apiProvider).todayBriefing();
    final spaceId = ref.read(meProvider).value?.activeSpaceId;
    if (spaceId != null) {
      ref.read(spaceSnapshotCacheProvider).putBriefing(spaceId, briefing);
    }
    return briefing;
  }

  void apply(Briefing briefing) {
    state = AsyncData(briefing);
  }

  Future<void> reload({bool quiet = false}) async {
    try {
      final briefing = await ref.read(apiProvider).todayBriefing();
      state = AsyncData(briefing);
      final spaceId = ref.read(meProvider).value?.activeSpaceId;
      if (spaceId != null) {
        ref.read(spaceSnapshotCacheProvider).putBriefing(spaceId, briefing);
      }
    } catch (error, stack) {
      if (!quiet || state.value == null) {
        state = AsyncError(error, stack);
      }
    }
  }
}

final spacesProvider =
    AsyncNotifierProvider<SpacesController, List<Space>>(SpacesController.new);

class SpacesController extends AsyncNotifier<List<Space>> {
  @override
  Future<List<Space>> build() async {
    ref.watch(authStateProvider);
    return ref.read(apiProvider).listSpaces();
  }

  void apply(List<Space> spaces) {
    state = AsyncData(List<Space>.of(spaces));
  }

  void upsert(Space space) {
    final current = List<Space>.of(state.value ?? const []);
    current.removeWhere((item) => item.id == space.id);
    current.add(space);
    state = AsyncData(current);
  }

  void removeById(String id) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.where((space) => space.id != id).toList());
  }

  Future<void> reload({bool quiet = false}) async {
    try {
      final spaces = await ref.read(apiProvider).listSpaces();
      state = AsyncData(spaces);
    } catch (error, stack) {
      if (!quiet || state.value == null) {
        state = AsyncError(error, stack);
      }
    }
  }
}

/// 懒同步：本地先改，过一会儿再和服务器对账；下拉刷新走 [pull]。
/// 状态值是月历缓存世代，下拉后加一，逼月历重拉。
final lazySyncProvider = NotifierProvider<LazySyncController, int>(
  LazySyncController.new,
);

class LazySyncController extends Notifier<int> {
  Timer? _debounce;

  @override
  int build() {
    ref.onDispose(() => _debounce?.cancel());
    return 0;
  }

  /// 操作后防抖对账，不打断界面。
  void schedule([Duration delay = const Duration(milliseconds: 450)]) {
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      unawaited(run(quiet: true, bumpCalendar: false));
    });
  }

  /// 本地写入已经落地：丢掉半路的旧列表，再排队对账。
  void settleWrite(String id, int gen) {
    ref.read(pendingTaskWritesProvider).settle(id, gen);
    _abandonTaskLists();
  }

  void protectLocalWrite() {
    _abandonTaskLists();
  }

  void _abandonTaskLists() {
    for (final status in taskListStatuses) {
      if (ref.exists(tasksProvider(status))) {
        ref.read(tasksProvider(status).notifier).abandonInflight();
      }
    }
  }

  /// 任意界面下拉：等全部拉完，并刷新月历缓存。
  Future<void> pull() => run(quiet: false, bumpCalendar: true);

  Future<void> run({
    required bool quiet,
    required bool bumpCalendar,
  }) async {
    _debounce?.cancel();
    final jobs = <Future<void>>[
      ref.read(meProvider.notifier).reload(quiet: quiet),
    ];
    if (ref.exists(briefingProvider)) {
      jobs.add(ref.read(briefingProvider.notifier).reload(quiet: quiet));
    }
    if (ref.exists(spacesProvider)) {
      jobs.add(ref.read(spacesProvider.notifier).reload(quiet: quiet));
    }
    if (ref.exists(noticesProvider)) {
      jobs.add(ref.read(noticesProvider.notifier).refresh(quiet: quiet));
    }
    for (final status in taskListStatuses) {
      if (ref.exists(tasksProvider(status))) {
        jobs.add(ref.read(tasksProvider(status).notifier).reload(quiet: quiet));
      }
    }
    await Future.wait(jobs);
    if (bumpCalendar) {
      state++;
    }
  }
}

/// 新建任务后，任务池列表滚到这一条。
final pendingScrollTaskIdProvider =
    NotifierProvider<PendingScrollTaskController, String?>(
  PendingScrollTaskController.new,
);

class PendingScrollTaskController extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String id) => state = id;

  void clear() => state = null;
}

final appThemeProvider = Provider<AppThemeKey>((ref) {
  if (!ref.watch(authStateProvider)) return AppThemeKey.mint;
  return AppThemeKey.fromKey(ref.watch(meProvider).value?.themeKey);
});

final noticesProvider =
    AsyncNotifierProvider<NoticesController, List<Notice>>(NoticesController.new);

class NoticesController extends AsyncNotifier<List<Notice>> {
  Timer? _timer;
  Timer? _dueTimer;
  Set<String> _seen = {};

  /// 仅一次的提醒到点后先本地挪进聚焦，记下这次挂起的代数，等服务端也挪走再放开。
  final Map<String, int> _holdGens = {};

  @override
  Future<List<Notice>> build() async {
    ref.watch(authStateProvider);
    ref.listen(tasksProvider('TODO'), (_, __) {
      _scheduleDueCheck();
    });
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _dueTimer?.cancel();
      _dueTimer = null;
    });
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(refresh(quiet: true));
    });
    scheduleMicrotask(() {
      if (!ref.mounted) {
        return;
      }
      _scheduleDueCheck();
    });
    try {
      final notices = await _fetch();
      _seen = notices.map((notice) => notice.id).toSet();
      return notices;
    } catch (_) {
      return const [];
    }
  }

  Future<void> refresh({bool quiet = true}) async {
    try {
      _promoteDueLocally();
      final notices = await _fetch();
      final fresh =
          notices.where((notice) => !_seen.contains(notice.id)).toList();
      _seen = notices.map((notice) => notice.id).toSet();
      state = AsyncData(notices);
      if (fresh.isNotEmpty || _holdGens.isNotEmpty) {
        await _reconcileTaskLists();
      }
    } catch (error, stack) {
      if (!quiet || state.value == null) {
        state = AsyncError(error, stack);
      }
    }
  }

  void _scheduleDueCheck() {
    _dueTimer?.cancel();
    _promoteDueLocally();
    final todoProvider = tasksProvider('TODO');
    if (!ref.exists(todoProvider)) {
      return;
    }
    final todo = ref.read(todoProvider).asData?.value;
    if (todo == null) {
      return;
    }
    final now = DateTime.now();
    DateTime? next;
    for (final task in todo) {
      final at = task.remindAt;
      if (task.priority != 'REMINDER' ||
          task.remindRepeat != 'ONCE' ||
          at == null ||
          !at.isAfter(now)) {
        continue;
      }
      if (next == null || at.isBefore(next)) {
        next = at;
      }
    }
    if (next == null) {
      return;
    }
    var delay = next.difference(now);
    if (delay < const Duration(milliseconds: 200)) {
      delay = const Duration(milliseconds: 200);
    }
    _dueTimer = Timer(delay, () {
      _promoteDueLocally();
      unawaited(refresh(quiet: true));
    });
  }

  /// 到点的仅一次提醒先从任务池拿掉，放进聚焦。循环提醒留在任务池，等服务端克隆。
  void _promoteDueLocally() {
    final todoProvider = tasksProvider('TODO');
    if (!ref.exists(todoProvider)) {
      return;
    }
    final todo = ref.read(todoProvider).asData?.value;
    if (todo == null || todo.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final due = [
      for (final task in todo)
        if (task.priority == 'REMINDER' &&
            task.remindRepeat == 'ONCE' &&
            task.remindAt != null &&
            !task.remindAt!.isAfter(now))
          task,
    ];
    if (due.isEmpty) {
      return;
    }
    final holds = ref.read(pendingTaskWritesProvider);
    final spaceId = ref.read(meProvider).asData?.value.activeSpaceId;
    final focusProvider = tasksProvider('FOCUS');
    final focusReady =
        ref.exists(focusProvider) && ref.read(focusProvider).hasValue;
    for (final task in due) {
      if (holds.isPending(task.id)) {
        if (_holdGens.containsKey(task.id)) {
          ref.read(todoProvider.notifier).removeById(task.id);
        }
        continue;
      }
      final moved = task.copyWith(status: 'FOCUS');
      _holdGens[task.id] = holds.begin(
        id: task.id,
        spaceId: spaceId,
        task: moved,
      );
      ref.read(todoProvider.notifier).removeById(task.id);
      if (focusReady) {
        ref.read(focusProvider.notifier).upsert(moved);
      }
    }
  }

  Future<void> _reconcileTaskLists() async {
    final api = ref.read(apiProvider);
    final serverTodo = await api.listTasks(status: 'TODO');
    final serverFocus = await api.listTasks(status: 'FOCUS');
    final stillPooling = serverTodo.map((task) => task.id).toSet();
    final holds = ref.read(pendingTaskWritesProvider);
    for (final entry in _holdGens.entries.toList()) {
      if (stillPooling.contains(entry.key)) {
        continue;
      }
      holds.settle(entry.key, entry.value);
      _holdGens.remove(entry.key);
    }
    final todoProvider = tasksProvider('TODO');
    if (ref.exists(todoProvider)) {
      ref.read(todoProvider.notifier).applyServer(serverTodo);
    }
    final focusProvider = tasksProvider('FOCUS');
    if (ref.exists(focusProvider)) {
      ref.read(focusProvider.notifier).applyServer(serverFocus);
    }
  }

  Future<void> markRead() async {
    final current = state.value ?? const <Notice>[];
    if (!current.any((notice) => notice.unread)) {
      return;
    }
    final readAt = DateTime.now();
    state = AsyncData([
      for (final notice in current)
        notice.unread
            ? Notice(
                id: notice.id,
                taskId: notice.taskId,
                title: notice.title,
                message: notice.message,
                createdAt: notice.createdAt,
                readAt: readAt,
              )
            : notice,
    ]);
    try {
      await ref.read(apiProvider).markNoticesRead();
    } catch (_) {
      unawaited(refresh());
    }
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    _seen = {};
    try {
      await ref.read(apiProvider).clearNotices();
    } catch (_) {
      unawaited(refresh());
    }
  }

  Future<List<Notice>> _fetch() {
    return ref.read(apiProvider).listNotices();
  }
}

/// 首页当前底栏入口（任务池 / 聚焦 / 完成 / 归档 / 设置）。
final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);

class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.todo;

  void setTab(HomeTab tab) => state = tab;
}

/// 设置里开了语音输入才算"能说"。还没拿到设置时先当作开着。
final voiceInputEnabledProvider = Provider<bool>((ref) {
  return ref.watch(meProvider).value?.voiceInputEnabled ?? true;
});

/// 浏览器麦克风权限；null 表示还没查过。
final micPermissionProvider =
    NotifierProvider<MicPermissionController, MicPermissionState?>(
  MicPermissionController.new,
);

class MicPermissionController extends Notifier<MicPermissionState?> {
  bool _askedOnOpen = false;

  @override
  MicPermissionState? build() => null;

  /// 只看不问。
  Future<MicPermissionState> refresh() async {
    final next = await MicrophoneAccess.query();
    state = next;
    return next;
  }

  /// 主动弹一次权限框。
  Future<MicPermissionState> request() async {
    final next = await MicrophoneAccess.request();
    state = next;
    return next;
  }

  /// 打开网页就把麦克风申请下来，长按加号时不用再分神点允许。
  /// 每次加载页面只做一次；已经允许 / 拒绝 / 地址不行的都不重复打扰。
  Future<void> ensureAskedOnOpen() async {
    if (_askedOnOpen || !kIsWeb) {
      return;
    }
    _askedOnOpen = true;
    if (!MicrophoneAccess.speechRecognitionSupported) {
      state = MicPermissionState.unsupported;
      return;
    }
    final current = await refresh();
    if (current == MicPermissionState.prompt ||
        current == MicPermissionState.unknown) {
      await request();
    }
  }
}
