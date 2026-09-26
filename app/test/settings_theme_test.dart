import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/api/api_client.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/screens/settings_screen.dart';
import 'package:flowdo/theme.dart';

void main() {
  testWidgets('settings exposes all account theme choices', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final me = Me(
      id: 'user',
      username: 'hello',
      archiveAfterDays: 7,
      focusLimit: 3,
      deleteArchivedAfterDays: 30,
      showArchiveTab: true,
      themeKey: 'hazeBlue',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          meProvider.overrideWith((_) async => me),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeKey.hazeBlue),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('闲云'), findsOneWidget);
    expect(find.text('远山'), findsOneWidget);
    expect(find.text('归途'), findsOneWidget);
    expect(find.text('微光'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('voice input switch follows the account and saves through the API',
      (tester) async {
    SharedPreferences.setMockInitialValues({'accessToken': 'token'});
    final prefs = await SharedPreferences.getInstance();
    final api = _RecordingMeApi(prefs);
    final me = Me(
      id: 'user',
      username: 'hello',
      archiveAfterDays: 7,
      focusLimit: 3,
      deleteArchivedAfterDays: 30,
      showArchiveTab: true,
      themeKey: 'mint',
      voiceInputEnabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          apiProvider.overrideWithValue(api),
          meProvider.overrideWith((_) async => me),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const ValueKey('voice-input-switch'));
    await tester.scrollUntilVisible(
      switchFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('长按加号说话'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(api.lastVoiceInputEnabled, isTrue);
  });

  testWidgets('failed theme switch shows an error snackbar', (tester) async {
    SharedPreferences.setMockInitialValues({'accessToken': 'token'});
    final prefs = await SharedPreferences.getInstance();
    final me = Me(
      id: 'user',
      username: 'hello',
      archiveAfterDays: 7,
      focusLimit: 3,
      deleteArchivedAfterDays: 30,
      showArchiveTab: true,
      themeKey: 'hazeBlue',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          apiProvider.overrideWithValue(_FailingMeApi(prefs)),
          meProvider.overrideWith((_) async => me),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeKey.hazeBlue),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('闲云'));
    await tester.pumpAndSettle();

    expect(find.text('主题没换上，服务端还不认这个字段。'), findsOneWidget);
  });
}

class _RecordingMeApi extends ApiClient {
  _RecordingMeApi(super.prefs);

  bool? lastVoiceInputEnabled;

  @override
  Future<Me> updateMe({
    int? archiveAfterDays,
    int? focusLimit,
    int? deleteArchivedAfterDays,
    bool? showArchiveTab,
    String? themeKey,
    bool? voiceInputEnabled,
  }) async {
    lastVoiceInputEnabled = voiceInputEnabled;
    return Me(
      id: 'user',
      username: 'hello',
      archiveAfterDays: 7,
      focusLimit: 3,
      deleteArchivedAfterDays: 30,
      showArchiveTab: true,
      themeKey: 'mint',
      voiceInputEnabled: voiceInputEnabled ?? true,
    );
  }
}

class _FailingMeApi extends ApiClient {
  _FailingMeApi(super.prefs);

  @override
  Future<Me> updateMe({
    int? archiveAfterDays,
    int? focusLimit,
    int? deleteArchivedAfterDays,
    bool? showArchiveTab,
    String? themeKey,
    bool? voiceInputEnabled,
  }) async {
    throw ApiException('主题没换上，服务端还不认这个字段。');
  }
}
