import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'models/briefing.dart';
import 'models/task.dart';
import 'models/user.dart';
import 'platform/microphone.dart';
import 'theme.dart';

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

  Future<void> login(String username, String password) async {
    await ref.read(apiProvider).login(username, password);
    state = true;
  }

  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    state = false;
  }
}

final meProvider = FutureProvider<Me>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).getMe();
});

final tasksProvider = FutureProvider.family<List<Task>, String>((ref, status) async {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).listTasks(status: status);
});

final briefingProvider = FutureProvider<Briefing>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).todayBriefing();
});

final appThemeProvider = Provider<AppThemeKey>((ref) {
  if (!ref.watch(authStateProvider)) return AppThemeKey.mint;
  return AppThemeKey.fromKey(ref.watch(meProvider).value?.themeKey);
});

/// 0 任务池, 1 聚焦, 2 完成
final homeTabProvider = NotifierProvider<HomeTabController, int>(
  HomeTabController.new,
);

class HomeTabController extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index.clamp(0, 2);
}

/// 账号开了语音输入才算"能说"。还没拿到账号信息时先当作开着。
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
