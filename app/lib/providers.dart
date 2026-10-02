import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'models/briefing.dart';
import 'models/space.dart';
import 'models/task.dart';
import 'models/user.dart';
import 'platform/microphone.dart';
import 'theme.dart';
import 'ui/focus_dock.dart';

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
    String? themeKey,
    bool? voiceInputEnabled,
    String? activeSpaceId,
  }) async {
    final me = await ref.read(apiProvider).updateMe(
          archiveAfterDays: archiveAfterDays,
          focusLimit: focusLimit,
          deleteArchivedAfterDays: deleteArchivedAfterDays,
          showArchiveTab: showArchiveTab,
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

  @override
  Future<List<Task>> build() async {
    ref.watch(authStateProvider);
    return ref.read(apiProvider).listTasks(status: status);
  }

  Future<void> reload({bool quiet = false}) async {
    try {
      final tasks = await ref.read(apiProvider).listTasks(status: status);
      state = AsyncData(tasks);
    } catch (error, stack) {
      if (!quiet || state.value == null) {
        state = AsyncError(error, stack);
      }
    }
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
    current.sort(_byPriorityThenRecent);
    state = AsyncData(current);
  }

  void replaceAll(List<Task> tasks) {
    state = AsyncData(List<Task>.of(tasks));
  }
}

int _priorityRank(String priority) {
  return switch (priority) {
    'HIGH' => 0,
    'MEDIUM' => 1,
    'LOW' => 2,
    _ => 9,
  };
}

int _byPriorityThenRecent(Task a, Task b) {
  final byPriority = _priorityRank(a.priority) - _priorityRank(b.priority);
  if (byPriority != 0) {
    return byPriority;
  }
  return b.updatedAt.compareTo(a.updatedAt);
}

const taskListStatuses = ['TODO', 'FOCUS', 'DONE', 'ARCHIVED'];

/// 当前空间的四个任务列表都作废，切空间后重新拉。
void invalidateTaskLists(WidgetRef ref) {
  for (final status in taskListStatuses) {
    ref.invalidate(tasksProvider(status));
  }
}

final briefingProvider =
    AsyncNotifierProvider<BriefingController, Briefing>(BriefingController.new);

class BriefingController extends AsyncNotifier<Briefing> {
  @override
  Future<Briefing> build() async {
    ref.watch(authStateProvider);
    return ref.read(apiProvider).todayBriefing();
  }

  Future<void> reload({bool quiet = false}) async {
    try {
      final briefing = await ref.read(apiProvider).todayBriefing();
      state = AsyncData(briefing);
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
