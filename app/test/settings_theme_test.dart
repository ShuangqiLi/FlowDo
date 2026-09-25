import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskmgr/models/user.dart';
import 'package:taskmgr/providers.dart';
import 'package:taskmgr/screens/settings_screen.dart';
import 'package:taskmgr/theme.dart';

void main() {
  testWidgets('settings exposes all account theme choices', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final me = Me(
      id: 'user',
      email: 'hello@flowdo.test',
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

    expect(find.text('薄荷绿'), findsOneWidget);
    expect(find.text('雾霾蓝'), findsOneWidget);
    expect(find.text('暖橘色'), findsOneWidget);
    expect(find.text('淡紫色'), findsOneWidget);
    expect(find.text('hello@flowdo.test'), findsOneWidget);
  });
}
