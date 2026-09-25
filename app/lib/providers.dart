import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'models/briefing.dart';
import 'models/task.dart';
import 'models/user.dart';
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

  Future<void> login(String email, String password) async {
    await ref.read(apiProvider).login(email, password);
    state = true;
  }

  Future<void> register(String email, String password) async {
    await ref.read(apiProvider).register(email, password);
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
