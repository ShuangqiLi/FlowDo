import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/about.dart';
import '../models/notice.dart';
import '../models/briefing.dart';
import '../models/space.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../ui/password_field.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._prefs);

  final SharedPreferences _prefs;

  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';

  String? get accessToken => _prefs.getString(_kAccess);

  bool get isLoggedIn => (accessToken ?? '').isNotEmpty;

  Future<void> _saveTokens(Map<String, dynamic> json) async {
    await _prefs.setString(_kAccess, json['accessToken'] as String);
    await _prefs.setString(_kRefresh, json['refreshToken'] as String);
  }

  Future<void> logout() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.base.resolve(path).replace(queryParameters: query);
  }

  Map<String, String> _headers({bool auth = true, bool jsonBody = false}) {
    final headers = <String, String>{};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    final token = accessToken;
    if (auth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
    bool retried = false,
  }) async {
    // 登录/改密要留着密码框，插件才能记住。其它写请求先拆掉残留的密码框，
    // 否则插件会把改任务状态当成更新密码。
    if (method != 'GET' &&
        path != '/auth/login' &&
        path != '/auth/change-password') {
      retireStrayPasswordFields();
    }
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response res;
    final headers = _headers(auth: auth, jsonBody: body != null);
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers);
        break;
      case 'POST':
        res = await http.post(uri, headers: headers, body: encoded);
        break;
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: encoded);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: headers);
        break;
      default:
        throw ApiException('Unsupported method $method');
    }

    if (res.statusCode == 401 && auth && !retried) {
      final ok = await _refresh();
      if (ok) {
        return _request(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
          retried: true,
        );
      }
    }

    if (res.statusCode >= 400) {
      String message = '请求没成功，稍后再试（${res.statusCode}）';
      try {
        final parsed = jsonDecode(res.body);
        if (parsed is Map && parsed['message'] != null) {
          final m = parsed['message'];
          message = m is List ? m.join(', ') : m.toString();
        }
      } catch (_) {}
      throw ApiException(message, res.statusCode);
    }

    if (res.body.isEmpty) {
      return null;
    }
    return jsonDecode(res.body);
  }

  Future<bool> _refresh() async {
    final refresh = _prefs.getString(_kRefresh);
    if (refresh == null || refresh.isEmpty) {
      return false;
    }
    try {
      final json = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': refresh},
        auth: false,
      );
      await _saveTokens(json as Map<String, dynamic>);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<bool> needsPasswordSetup() async {
    final json = await _request('POST', '/auth/status', auth: false);
    final map = json as Map<String, dynamic>;
    return map['needsSetup'] == true;
  }

  Future<void> setupPassword(String password) async {
    final json = await _request(
      'POST',
      '/auth/setup',
      body: {'password': password},
      auth: false,
    );
    await _saveTokens(json as Map<String, dynamic>);
  }

  Future<void> login(String password) async {
    final json = await _request(
      'POST',
      '/auth/login',
      body: {'password': password},
      auth: false,
    );
    await _saveTokens(json as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<Me> getMe() async {
    final json = await _request('GET', '/me');
    return Me.fromJson(json as Map<String, dynamic>);
  }

  Future<Me> updateMe({
    int? archiveAfterDays,
    int? focusLimit,
    int? deleteArchivedAfterDays,
    bool? showArchiveTab,
    bool? showRecurringReminders,
    String? themeKey,
    bool? voiceInputEnabled,
    String? activeSpaceId,
  }) async {
    final body = <String, dynamic>{};
    if (archiveAfterDays != null) {
      body['archiveAfterDays'] = archiveAfterDays;
    }
    if (focusLimit != null) {
      body['focusLimit'] = focusLimit;
    }
    if (deleteArchivedAfterDays != null) {
      body['deleteArchivedAfterDays'] = deleteArchivedAfterDays;
    }
    if (showArchiveTab != null) {
      body['showArchiveTab'] = showArchiveTab;
    }
    if (showRecurringReminders != null) {
      body['showRecurringReminders'] = showRecurringReminders;
    }
    if (themeKey != null) {
      body['themeKey'] = themeKey;
    }
    if (voiceInputEnabled != null) {
      body['voiceInputEnabled'] = voiceInputEnabled;
    }
    if (activeSpaceId != null) {
      body['activeSpaceId'] = activeSpaceId;
    }
    final json = await _request('PATCH', '/me', body: body);
    return Me.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Task>> listTasks({String? status}) async {
    final json = await _request(
      'GET',
      '/tasks',
      query: status == null ? null : {'status': status, 'sort': 'priority'},
    );
    return (json as List<dynamic>)
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Task> createTask({
    required String title,
    String? body,
    String? priority,
  }) async {
    final payload = <String, dynamic>{'title': title};
    if (body != null && body.isNotEmpty) {
      payload['body'] = body;
    }
    if (priority != null) {
      payload['priority'] = priority;
    }
    final json = await _request('POST', '/tasks', body: payload);
    return Task.fromJson(json as Map<String, dynamic>);
  }

  Future<Task> updateTask(
    String id, {
    String? title,
    String? body,
    String? priority,
    DateTime? remindAt,
    bool clearRemindAt = false,
    String? remindRepeat,
    String? remindCron,
    bool clearRemindCron = false,
    bool? remindLunar,
    String? status,
    String? spaceId,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (body != null) payload['body'] = body;
    if (priority != null) payload['priority'] = priority;
    if (clearRemindAt) {
      payload['remindAt'] = null;
    } else if (remindAt != null) {
      payload['remindAt'] = remindAt.toUtc().toIso8601String();
    }
    if (remindRepeat != null) payload['remindRepeat'] = remindRepeat;
    if (clearRemindCron) {
      payload['remindCron'] = null;
    } else if (remindCron != null) {
      payload['remindCron'] = remindCron;
    }
    if (remindLunar != null) payload['remindLunar'] = remindLunar;
    if (status != null) payload['status'] = status;
    if (spaceId != null) payload['spaceId'] = spaceId;
    final json = await _request('PATCH', '/tasks/$id', body: payload);
    return Task.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteTask(String id) async {
    await _request('DELETE', '/tasks/$id');
  }

  Future<List<Notice>> listNotices() async {
    final json = await _request('GET', '/notices');
    return (json as List<dynamic>)
        .map((e) => Notice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNoticesRead() async {
    await _request('POST', '/notices/read');
  }

  Future<void> clearNotices() async {
    await _request('DELETE', '/notices');
  }

  Map<String, String> _tzQuery([Map<String, String>? extra]) {
    return {
      'tzOffset': '${DateTime.now().timeZoneOffset.inMinutes}',
      ...?extra,
    };
  }

  Future<Briefing> todayBriefing() async {
    final json = await _request('GET', '/briefing/today', query: _tzQuery());
    return Briefing.fromJson(json as Map<String, dynamic>);
  }

  Future<MonthReview> monthBriefing(int year, int month) async {
    final json = await _request(
      'GET',
      '/briefing/month',
      query: _tzQuery({'year': '$year', 'month': '$month'}),
    );
    return MonthReview.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Space>> listSpaces() async {
    final json = await _request('GET', '/spaces');
    return (json as List<dynamic>)
        .map((e) => Space.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Space> createSpace(String name) async {
    final json = await _request('POST', '/spaces', body: {'name': name});
    return Space.fromJson(json as Map<String, dynamic>);
  }

  Future<Space> renameSpace(String id, String name) async {
    final json = await _request('PATCH', '/spaces/$id', body: {'name': name});
    return Space.fromJson(json as Map<String, dynamic>);
  }

  Future<int> spaceTaskCount(String id) async {
    final json =
        await _request('GET', '/spaces/$id/task-count') as Map<String, dynamic>;
    return (json['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteSpace(String id) async {
    await _request('DELETE', '/spaces/$id');
  }

  /// [check] 为 true 时向 GitHub 查一次有没有新版本；否则只返回当前版本。
  Future<AboutInfo> about({bool check = false}) async {
    final path = check ? '/system/about?check=1' : '/system/about';
    final json = await _request('GET', path);
    return AboutInfo.fromJson(json as Map<String, dynamic>);
  }

  /// 开始把网页和接口换成 GitHub 上的新版本。返回要换到的版本号。
  Future<String> startUpdate() async {
    final json =
        await _request('POST', '/system/update') as Map<String, dynamic>;
    return json['target'] as String;
  }

  Future<({int archived, int deleted})> runArchive() async {
    final json = await _request('POST', '/archive/run') as Map<String, dynamic>;
    return (
      archived: (json['archived'] as int?) ?? 0,
      deleted: (json['deleted'] as int?) ?? 0,
    );
  }
}
