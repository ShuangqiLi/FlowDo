import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/main.dart';
import 'package:flowdo/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const FlowDoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('随随办办'), findsOneWidget);
    expect(find.text('FlowDo'), findsOneWidget);
    expect(find.text('无压力任务管理'), findsOneWidget);
    expect(find.text('随随办办，总会办完。'), findsOneWidget);
    expect(find.text('Go with the flow, get it done.'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
    expect(find.text('确认密码'), findsNothing);
  });

  testWidgets('register mode shows confirm password', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const FlowDoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final register = find.text('还没有账号？来注册');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pumpAndSettle();
    expect(find.text('确认密码'), findsOneWidget);
    expect(find.text('注册'), findsWidgets);
  });
}
