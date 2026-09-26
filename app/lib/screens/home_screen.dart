import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/add_task_fab.dart';
import '../ui/flowdo_page_route.dart';
import '../ui/focus_dock.dart';
import '../ui/swipe_away.dart';
import 'archive_screen.dart';
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

  @override
  void initState() {
    super.initState();
    final initial = ref.read(homeTabProvider).clamp(0, 2);
    _pages = PageController(initialPage: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
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

  /// 账号开着语音输入，就在进首页时把麦克风权限申请好；长按加号时不用再分神点允许。
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

  void _goTab(int index) {
    final next = index.clamp(0, 2);
    if (ref.read(homeTabProvider) == next) {
      return;
    }
    // 只改 provider；PageView 由 listen 跟过去，避免连点两次 animate。
    ref.read(homeTabProvider.notifier).setIndex(next);
  }

  Future<void> _openSettings() async {
    await _closeBriefing();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      FlowDoPageRoute(
        swipeFromLeftEdgeOnly: false,
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _openArchive() async {
    await _closeBriefing();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      FlowDoPageRoute(
        swipeFromLeftEdgeOnly: false,
        builder: (_) => const ArchiveScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabProvider).clamp(0, 2);
    final showArchive = ref.watch(meProvider).value?.showArchiveTab ?? true;
    // 外部改 tab（加号建完、聚焦满了）时跟上 PageView。
    ref.listen<int>(homeTabProvider, (prev, next) {
      final page = next.clamp(0, 2);
      if (!_pages.hasClients) {
        return;
      }
      final current = _pages.page?.round() ?? index;
      if (current == page) {
        return;
      }
      _pages.animateToPage(
        page,
        duration: AppMotion.standard,
        curve: AppMotion.curve,
      );
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
              title: _showBriefing ? const Text('今日看看') : null,
              automaticallyImplyLeading: false,
              leadingWidth: showArchive && !_showBriefing ? 104 : 56,
              leading: _showBriefing
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('open-settings'),
                          tooltip: '设置',
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: _openSettings,
                        ),
                        if (showArchive)
                          IconButton(
                            key: const ValueKey('open-archive'),
                            tooltip: '归档',
                            icon: const Icon(Icons.archive_rounded),
                            onPressed: _openArchive,
                          ),
                      ],
                    ),
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
                PageView(
                  controller: _pages,
                  allowImplicitScrolling: false,
                  onPageChanged: (i) {
                    ref.read(homeTabProvider.notifier).setIndex(i);
                    if (_showBriefing) {
                      _closeBriefing();
                    }
                  },
                  children: const [
                    TaskListScreen(status: 'TODO'),
                    TaskListScreen(status: 'FOCUS'),
                    TaskListScreen(status: 'DONE'),
                  ],
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
                selectedIndex: index,
                onSelected: (i) {
                  _goTab(i);
                  if (_showBriefing) {
                    _closeBriefing();
                  }
                },
              ),
            ),
          ),
          AddTaskFab(visible: !_showBriefing),
        ],
      ),
    );
  }
}
