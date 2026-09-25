import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import '../ui/add_task_fab.dart';
import '../ui/flowdo_page_route.dart';
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
              child: _FocusDock(
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

/// 半椭圆台面底栏：三个方块围弧而立（无 3D 透视，减轻滑动时的合成开销）。
class _FocusDock extends StatelessWidget {
  const _FocusDock({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _arcHeight = 118;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flow = context.flowColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _arcHeight + bottomInset,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SemiEllipseDockPainter(
                  fill: flow.card,
                  rim: scheme.outlineVariant,
                  bottomInset: bottomInset,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset,
              height: _arcHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  Offset onArc(double t) {
                    final angle = math.pi * (1 - t);
                    final cx = w / 2;
                    final cy = h + 2;
                    final rx = w * 0.36;
                    final ry = h * 0.68;
                    return Offset(
                      cx + rx * math.cos(angle),
                      cy - ry * math.sin(angle),
                    );
                  }

                  final pool = onArc(0.14);
                  final focus = onArc(0.5);
                  final done = onArc(0.86);

                  Widget place({
                    required Offset c,
                    required Widget child,
                  }) {
                    return Positioned(
                      left: c.dx - 36,
                      top: c.dy - 56,
                      width: 72,
                      height: 78,
                      child: child,
                    );
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      place(
                        c: pool,
                        child: _DockBlock(
                          selected: selectedIndex == 0,
                          icon: Icons.inbox_rounded,
                          label: '任务池',
                          onTap: () => onSelected(0),
                        ),
                      ),
                      place(
                        c: done,
                        child: _DockBlock(
                          selected: selectedIndex == 2,
                          icon: Icons.check_circle_rounded,
                          label: '完成',
                          onTap: () => onSelected(2),
                        ),
                      ),
                      place(
                        c: focus,
                        child: _DockBlock(
                          selected: selectedIndex == 1,
                          icon: Icons.center_focus_strong_rounded,
                          label: '聚焦',
                          onTap: () => onSelected(1),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockBlock extends StatelessWidget {
  const _DockBlock({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flow = context.flowColors;
    final face = selected ? scheme.primaryContainer : flow.card;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: face,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.35)
                    : scheme.outlineVariant,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: fg, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部半椭圆台面（Flat：纯色填充 + 发丝描边）。
class _SemiEllipseDockPainter extends CustomPainter {
  const _SemiEllipseDockPainter({
    required this.fill,
    required this.rim,
    required this.bottomInset,
  });

  final Color fill;
  final Color rim;
  final double bottomInset;

  @override
  void paint(Canvas canvas, Size size) {
    final arcBottom = size.height - bottomInset;
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, arcBottom + arcBottom * 0.08),
      width: size.width * 1.08,
      height: arcBottom * 1.85,
    );

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, arcBottom)
      ..arcTo(oval, math.pi, -math.pi, false)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = fill);

    final rimPaint = Paint()
      ..color = rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(Path()..addArc(oval, math.pi, -math.pi), rimPaint);
  }

  @override
  bool shouldRepaint(covariant _SemiEllipseDockPainter oldDelegate) {
    return fill != oldDelegate.fill ||
        rim != oldDelegate.rim ||
        bottomInset != oldDelegate.bottomInset;
  }
}
