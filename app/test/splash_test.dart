import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowdo/main.dart';
import 'package:flowdo/ui/flowdo_logo.dart';
import 'package:flowdo/ui/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot shows splash then login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FlowDoBoot());
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(FlowDoLogo), findsOneWidget);
    expect(find.text('随随办办'), findsOneWidget);
    expect(find.text('FlowDo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('登录'), findsWidgets);
  });
}
