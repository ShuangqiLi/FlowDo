import 'dart:math' as math;

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
          title: _showBriefing ? const Text('今日看看') : null,
          automaticallyImplyLeading: false,
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
                  ? _SwipeToClose(
                      key: const ValueKey('briefing-panel'),
                      onClose: _closeBriefing,
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

/// 往右滑关掉今日看看。
///
/// 这里不用 `Dismissible`：它自己维护一套「已滑走」状态，和 `_showBriefing`
/// 是两套真相。滑完面板会立刻塌成零高度，但要等收起动画跑完才回调，中间那段
/// 时间按钮显示的是关闭态、面板却已经看不见；动画要是没跑完就一直卡在那儿。
class _SwipeToClose extends StatefulWidget {
  const _SwipeToClose({super.key, required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  State<_SwipeToClose> createState() => _SwipeToCloseState();
}

class _SwipeToCloseState extends State<_SwipeToClose> {
  double _dragX = 0;
  bool _dragging = false;

  void _reset() {
    setState(() {
      _dragging = false;
      _dragX = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (details) {
        setState(() => _dragX = math.max(0, _dragX + details.delta.dx));
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 700 || _dragX > width * 0.3) {
          widget.onClose();
          return;
        }
        _reset();
      },
      onHorizontalDragCancel: _reset,
      child: AnimatedSlide(
        offset: Offset(width == 0 ? 0 : _dragX / width, 0),
        duration: _dragging ? Duration.zero : AppMotion.quick,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}
