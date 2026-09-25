import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const TaskMgrApp(),
    ),
  );
}

class TaskMgrApp extends ConsumerWidget {
  const TaskMgrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authStateProvider);
    return MaterialApp(
      title: '随随办办 FlowDo',
      theme: buildAppTheme(),
      home: loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
