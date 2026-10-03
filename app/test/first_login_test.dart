import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/main.dart';
import 'package:flowdo/models/user.dart';
import 'package:flowdo/providers.dart';
import 'package:flowdo/screens/change_password_screen.dart';
import 'package:flowdo/screens/home_screen.dart';
import 'provider_overrides.dart';

Me _me({required bool mustChangePassword}) => Me(
      id: 'default',
      archiveAfterDays: 7,
      focusLimit: 3,
      deleteArchivedAfterDays: 30,
      showArchiveTab: true,
      themeKey: 'mint',
      mustChangePassword: mustChangePassword,
    );

void main() {
  testWidgets('first visit asks to set a password before home', (tester) async {
    SharedPreferences.setMockInitialValues({'accessToken': 'token'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          meOverride(_me(mustChangePassword: true)),
        ],
        child: const FlowDoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('设一个密码'), findsOneWidget);
    expect(find.text('再输一次'), findsOneWidget);
  });
}
