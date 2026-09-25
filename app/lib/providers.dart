import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'models/briefing.dart';
import 'models/task.dart';
import 'models/user.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefs must be overridden');
});

final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(prefsProvider));
});

final authStateProvider = StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref.watch(apiProvider));
});

class AuthController extends StateNotifier<bool> {
  AuthController(this._api) : super(_api.isLoggedIn);
  final ApiClient _api;

  Future<void> login(String email, String password) async {
    await _api.login(email, password);
    state = true;
  }

  Future<void> register(String email, String password) async {
    await _api.register(email, password);
    state = true;
  }

  Future<void> logout() async {
    await _api.logout();
    state = false;
  }
}

final meProvider = FutureProvider<Me>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).getMe();
});

final tasksProvider =
    FutureProvider.family<List<Task>, String>((ref, status) async {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).listTasks(status: status);
});

final briefingProvider = FutureProvider<Briefing>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(apiProvider).todayBriefing();
});

/// 0 任务池, 1 聚焦, 2 完成, 3 归档, 4 设置
final homeTabProvider = StateProvider<int>((ref) => 0);
