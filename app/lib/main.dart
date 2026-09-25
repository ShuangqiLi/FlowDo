import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先画开屏，再去加载本地配置，避免白屏空等。
  runApp(const FlowDoBoot());
}

/// 启动壳：prefs 未就绪时显示开屏，就绪后切入正式 App。
class FlowDoBoot extends StatefulWidget {
  const FlowDoBoot({super.key});

  @override
  State<FlowDoBoot> createState() => _FlowDoBootState();
}

class _FlowDoBootState extends State<FlowDoBoot> {
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final started = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    // 太快闪一下也别扭，至少让 logo 露个脸。
    const minShow = Duration(milliseconds: 600);
    final wait = minShow - DateTime.now().difference(started);
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    if (!mounted) {
      return;
    }
    setState(() => _prefs = prefs);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) {
      return MaterialApp(
        title: '随随办办 FlowDo',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(AppThemeKey.mint),
        home: const SplashScreen(),
      );
    }
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
      home: loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
