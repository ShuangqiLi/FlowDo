import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'screens/change_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 网页上 index.html 自带开屏，Flutter 这边不再画第二个：
  // 先把本地配置读好，第一帧直接是登录页或首页，HTML 开屏淡出就到位。
  final prefs = await SharedPreferences.getInstance();
  runApp(FlowDoBoot(prefs: prefs));
}

/// 启动壳：把已就绪的本地配置交给 ProviderScope。
class FlowDoBoot extends StatelessWidget {
  const FlowDoBoot({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const FlowDoApp(),
    );
  }
}

class FlowDoApp extends ConsumerWidget {
  const FlowDoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authStateProvider);
    final themeKey = ref.watch(appThemeProvider);
    return MaterialApp(
      title: '随随办办 FlowDo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeKey),
      themeAnimationDuration: AppMotion.standard,
      themeAnimationCurve: AppMotion.curve,
      scrollBehavior: const FlowDoScrollBehavior(),
      home: _RootSwitcher(loggedIn: loggedIn),
    );
  }
}

/// 登录 / 强制改密 / 首页之间淡入淡出，不要硬切。
class _RootSwitcher extends ConsumerWidget {
  const _RootSwitcher({required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child;
    if (!loggedIn) {
      child = const LoginScreen(key: ValueKey('login'));
    } else {
      final me = ref.watch(meProvider);
      final mustChange = me.value?.mustChangePassword ?? false;
      if (me.isLoading && !me.hasValue) {
        child = ColoredBox(
          key: const ValueKey('loading'),
          color: context.flowColors.canvas,
        );
      } else if (mustChange) {
        child = const ChangePasswordScreen(key: ValueKey('change-password'));
      } else {
        child = const HomeScreen(key: ValueKey('home'));
      }
    }
    return AnimatedSwitcher(
      duration: AppMotion.standard,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.curve,
      child: child,
    );
  }
}
