import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/api/api_client.dart';
import 'package:flowdo/models/about.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/screens/about_screen.dart';
import 'package:flowdo/screens/settings_screen.dart';
import 'package:flowdo/theme.dart';

void main() {
  testWidgets('about page shows the current version when already up to date', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          apiProvider.overrideWithValue(
            _AboutApi(
              prefs,
              const AboutInfo(
                version: '0.5.0',
                latest: '0.5.0',
                updateAvailable: false,
                reachable: true,
                canUpdate: true,
                phase: 'idle',
                message: null,
                target: null,
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前版本 0.5.0'), findsOneWidget);
    expect(find.text('已经是最新的。'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-update')), findsNothing);
  });

  testWidgets('about page offers a one-tap update when a newer release exists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _AboutApi(
      prefs,
      const AboutInfo(
        version: '0.5.0',
        latest: '0.6.0',
        updateAvailable: true,
        reachable: true,
        canUpdate: true,
        phase: 'idle',
        message: null,
        target: null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          apiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('0.6.0'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('about-update')));
    await tester.pump();
    expect(api.starts, 1);
  });

  testWidgets('settings opens the about page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          apiProvider.overrideWithValue(
            _AboutApi(
              prefs,
              const AboutInfo(
                version: '0.5.0',
                latest: null,
                updateAvailable: false,
                reachable: false,
                canUpdate: false,
                phase: 'idle',
                message: null,
                target: null,
              ),
            ),
          ),
          meProvider.overrideWith(
            (_) async => Me(
              id: 'user',
              username: 'hello',
              archiveAfterDays: 7,
              focusLimit: 3,
              deleteArchivedAfterDays: 30,
              showArchiveTab: true,
              themeKey: 'mint',
            ),
          ),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('关于随随办办'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('关于随随办办'));
    await tester.pumpAndSettle();
    expect(find.text('当前版本 0.5.0'), findsOneWidget);
    expect(find.textContaining('连不上 GitHub'), findsOneWidget);
  });
}

class _AboutApi extends ApiClient {
  _AboutApi(super.prefs, this.info);

  final AboutInfo info;
  int starts = 0;

  @override
  Future<AboutInfo> about() async => info;

  @override
  Future<String> startUpdate() async {
    starts += 1;
    return info.latest ?? info.version;
  }
}
