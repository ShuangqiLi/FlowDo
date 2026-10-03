import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/add_task_fab.dart';
import '../ui/briefing_clock_button.dart';
import '../ui/password_field.dart';
import '../ui/focus_dock.dart';
import '../ui/space_switcher.dart';
import '../ui/swipe_away.dart';
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
  late final PageController _pages;
  /// 无限翻页的中间基数，逻辑页 = (page - base) % tabCount。
  static const int _loopBase = 10000;
  List<HomeTab> _tabs = homeTabsFor(showArchive: true);
  var _syncingPage = false;

  @override
  void initState() {
    super.initState();
    final showArchive = ref.read(meProvider).value?.showArchiveTab ?? false;
    _tabs = homeTabsFor(showArchive: showArchive);
    final initial = ref.read(homeTabProvider);
    final index = _tabs.indexOf(initial);
    _pages = PageController(
      initialPage: _loopBase + (index < 0 ? 0 : index),
    );
    retireStrayPasswordFields();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      retireStrayPasswordFields();
      _maybeOpenBriefing();
      _maybeAskMic(ref.read(meProvider).value);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
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

  void _maybeAskMic(Me? me) {
    if (me == null || !me.voiceInputEnabled || !AddTaskFab.voiceSupported) {
      return;
    }
    ref.read(micPermissionProvider.notifier).ensureAskedOnOpen();
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

  int _logicalIndex(int page) {
    final n = _tabs.length;
    if (n == 0) {
      return 0;
    }
    return ((page - _loopBase) % n + n) % n;
  }

  void _goTab(HomeTab tab) {
    if (!_tabs.contains(tab)) {
      tab = HomeTab.todo;
    }
    if (ref.read(homeTabProvider) == tab) {
      return;
    }
    ref.read(homeTabProvider.notifier).setTab(tab);
  }

  void _jumpToTab(HomeTab tab) {
    if (!_pages.hasClients) {
      return;
    }
    final index = _tabs.indexOf(tab);
    if (index < 0) {
      return;
    }
    final current = _pages.page?.round() ?? _loopBase;
    final logical = _logicalIndex(current);
    if (logical == index) {
      return;
    }
    _syncingPage = true;
    _pages.jumpToPage(current - logical + index);
    _syncingPage = false;
  }

  Widget _pageFor(HomeTab tab) {
    return switch (tab) {
      HomeTab.todo => const TaskListScreen(status: 'TODO'),
      HomeTab.focus => const TaskListScreen(status: 'FOCUS'),
      HomeTab.done => const TaskListScreen(status: 'DONE'),
      HomeTab.archive => const TaskListScreen(status: 'ARCHIVED'),
      HomeTab.settings => const SettingsScreen(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final showArchive = ref.watch(meProvider).value?.showArchiveTab ?? false;
    final tabs = homeTabsFor(showArchive: showArchive);
    final selected = ref.watch(homeTabProvider);
    final effectiveSelected =
        tabs.contains(selected) ? selected : HomeTab.todo;

    if (tabs.length != _tabs.length ||
        !_listEquals(tabs, _tabs)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _tabs = tabs);
        if (!tabs.contains(ref.read(homeTabProvider))) {
          ref.read(homeTabProvider.notifier).setTab(HomeTab.todo);
        }
        _jumpToTab(ref.read(homeTabProvider));
      });
    }

    ref.listen<HomeTab>(homeTabProvider, (prev, next) {
      if (!_tabs.contains(next)) {
        return;
      }
      _jumpToTab(next);
    });
    ref.listen<AsyncValue<Me>>(meProvider, (prev, next) {
      _maybeAskMic(next.value);
    });

    return PopScope(
      canPop: !_showBriefing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeBriefing();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: _showBriefing ? const Text('今日看看') : const SpaceSwitcher(),
              titleSpacing: 16,
              automaticallyImplyLeading: false,
              actions: [
                BriefingClockButton(
                  open: _showBriefing,
                  onPressed: _showBriefing ? _closeBriefing : _openBriefing,
                ),
              ],
            ),
            body: Stack(
              children: [
                ScrollConfiguration(
                  behavior: const HomePageScrollBehavior(),
                  child: PageView.builder(
                    controller: _pages,
                    allowImplicitScrolling: false,
                    onPageChanged: (page) {
                      if (_syncingPage) {
                        return;
                      }
                      final tab = _tabs[_logicalIndex(page)];
                      ref.read(homeTabProvider.notifier).setTab(tab);
                      if (_showBriefing) {
                        _closeBriefing();
                      }
                    },
                    itemBuilder: (context, page) {
                      final tab = _tabs[_logicalIndex(page)];
                      return KeyedSubtree(
                        key: ValueKey('page-$tab'),
                        child: _pageFor(tab),
                      );
                    },
                  ),
                ),
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
                      ? SwipeAway(
                          key: const ValueKey('briefing-panel'),
                          avoidHorizontalScrollers: true,
                          onAway: _closeBriefing,
                          child: const BriefingScreen(),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('briefing-hidden'),
                        ),
                ),
              ],
            ),
            bottomNavigationBar: RepaintBoundary(
              child: FocusDock(
                tabs: tabs,
                selected: effectiveSelected,
                onSelected: (tab) {
                  _goTab(tab);
                  if (_showBriefing) {
                    _closeBriefing();
                  }
                },
              ),
            ),
          ),
          AddTaskFab(
            visible: !_showBriefing &&
                effectiveSelected != HomeTab.settings &&
                effectiveSelected != HomeTab.archive,
          ),
        ],
      ),
    );
  }
}

bool _listEquals(List<HomeTab> a, List<HomeTab> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
