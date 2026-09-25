import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/briefing.dart';
import '../models/task.dart';
import '../models/user.dart';

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

  static const _kBase = 'apiBaseUrl';
  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';

  String get baseUrl => _prefs.getString(_kBase) ?? 'http://127.0.0.1:3000';

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/$'), '');
    await _prefs.setString(_kBase, trimmed);
  }

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
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
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

  Future<void> register(String email, String password) async {
    final json = await _request(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password},
      auth: false,
    );
    await _saveTokens(json as Map<String, dynamic>);
  }

  Future<void> login(String email, String password) async {
    final json = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    await _saveTokens(json as Map<String, dynamic>);
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
    String? themeKey,
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
    if (themeKey != null) {
      body['themeKey'] = themeKey;
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
    return (json as List<dynamic>).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
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
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (body != null) payload['body'] = body;
    if (priority != null) payload['priority'] = priority;
    if (status != null) payload['status'] = status;
    final json = await _request('PATCH', '/tasks/$id', body: payload);
    return Task.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteTask(String id) async {
    await _request('DELETE', '/tasks/$id');
  }

  Future<Briefing> todayBriefing() async {
    final json = await _request('GET', '/briefing/today');
    return Briefing.fromJson(json as Map<String, dynamic>);
  }

  Future<({int archived, int deleted})> runArchive() async {
    final json = await _request('POST', '/archive/run') as Map<String, dynamic>;
    return (
      archived: (json['archived'] as int?) ?? 0,
      deleted: (json['deleted'] as int?) ?? 0,
    );
  }
}
