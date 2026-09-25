import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import 'briefing_screen.dart';
import 'settings_screen.dart';
import 'task_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showBriefing = false;
  bool _autoOpenedBriefing = false;

  static const _titles = ['任务池', '聚焦', '完成', '归档', '设置'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeOpenBriefing();
    });
  }

  Future<void> _maybeOpenBriefing() async {
    if (!mounted || _autoOpenedBriefing) {
      return;
    }
    final prefs = ref.read(prefsProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final last = prefs.getString('lastBriefingDate');
    if (last == today) {
      return;
    }
    _autoOpenedBriefing = true;
    _openBriefing();
  }

  void _openBriefing() {
    if (_showBriefing) {
      return;
    }
    setState(() => _showBriefing = true);
  }

  Future<void> _closeBriefing() async {
    if (!_showBriefing) {
      return;
    }
    setState(() => _showBriefing = false);
    final prefs = ref.read(prefsProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('lastBriefingDate', today);
  }

  int _visualIndex(int real, bool showArchive) {
    if (showArchive) {
      return real;
    }
    if (real >= 3) {
      return real - 1;
    }
    return real;
  }

  int _realIndex(int visual, bool showArchive) {
    if (showArchive) {
      return visual;
    }
    if (visual >= 3) {
      return visual + 1;
    }
    return visual;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TaskListScreen(status: 'TODO'),
      const TaskListScreen(status: 'FOCUS'),
      const TaskListScreen(status: 'DONE'),
      const TaskListScreen(status: 'ARCHIVED'),
      const SettingsScreen(),
    ];
    final showArchive = ref.watch(meProvider).value?.showArchiveTab ?? true;
    var index = ref.watch(homeTabProvider);
    if (!showArchive && index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(homeTabProvider) == 3) {
          ref.read(homeTabProvider.notifier).setIndex(4);
        }
      });
      index = 4;
    }
    final scheme = Theme.of(context).colorScheme;
    final visual = _visualIndex(index, showArchive);

    return PopScope(
      canPop: !_showBriefing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeBriefing();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_showBriefing ? '今日看看' : _titles[index]),
          actions: [
            IconButton(
              tooltip: _showBriefing ? '关掉今日看看' : '今日看看',
              icon: Icon(
                _showBriefing ? Icons.close : Icons.wb_sunny_outlined,
              ),
              onPressed: _showBriefing ? _closeBriefing : _openBriefing,
            ),
          ],
        ),
        body: Stack(
          children: [
            IndexedStack(index: index, children: pages),
            AnimatedSwitcher(
              duration: AppMotion.standard,
              switchInCurve: AppMotion.curve,
              switchOutCurve: AppMotion.curve,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _showBriefing
                  ? Dismissible(
                      key: const ValueKey('briefing-panel'),
                      direction: DismissDirection.startToEnd,
                      onDismissed: (_) => _closeBriefing(),
                      background: ColoredBox(color: scheme.surface),
                      child: const BriefingScreen(),
                    )
                  : const SizedBox.shrink(key: ValueKey('briefing-hidden')),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: visual,
          onDestinationSelected: (i) {
            ref.read(homeTabProvider.notifier).setIndex(
                  _realIndex(i, showArchive),
                );
            _closeBriefing();
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.inbox_rounded),
              label: '任务池',
            ),
            const NavigationDestination(
              icon: Icon(Icons.center_focus_strong_rounded),
              label: '聚焦',
            ),
            const NavigationDestination(
              icon: Icon(Icons.check_circle_rounded),
              label: '完成',
            ),
            if (showArchive)
              const NavigationDestination(
                icon: Icon(Icons.archive_rounded),
                label: '归档',
              ),
            const NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
