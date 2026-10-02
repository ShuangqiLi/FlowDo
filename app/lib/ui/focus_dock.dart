import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// 首页底栏入口。归档是否出现由当前空间的 showArchiveTab 决定。
enum HomeTab {
  todo,
  focus,
  done,
  archive,
  settings,
}

extension HomeTabX on HomeTab {
  String get label => switch (this) {
        HomeTab.todo => '任务池',
        HomeTab.focus => '聚焦',
        HomeTab.done => '完成',
        HomeTab.archive => '归档',
        HomeTab.settings => '设置',
      };

  IconData get icon => switch (this) {
        HomeTab.todo => Icons.inbox_outlined,
        HomeTab.focus => Icons.center_focus_strong_outlined,
        HomeTab.done => Icons.check_circle_outline_rounded,
        HomeTab.archive => Icons.archive_outlined,
        HomeTab.settings => Icons.settings_outlined,
      };

  IconData get selectedIcon => switch (this) {
        HomeTab.todo => Icons.inbox_rounded,
        HomeTab.focus => Icons.center_focus_strong_rounded,
        HomeTab.done => Icons.check_circle_rounded,
        HomeTab.archive => Icons.archive_rounded,
        HomeTab.settings => Icons.settings_rounded,
      };
}

List<HomeTab> homeTabsFor({required bool showArchive}) => [
      HomeTab.todo,
      HomeTab.focus,
      HomeTab.done,
      if (showArchive) HomeTab.archive,
      HomeTab.settings,
    ];

/// 悬浮胶囊底栏。选中态是等宽浅色药丸，不闪矩形水波。
class FocusDock extends StatelessWidget {
  const FocusDock({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<HomeTab> tabs;
  final HomeTab selected;
  final ValueChanged<HomeTab> onSelected;

  /// 不含底部安全区。FAB 用它躲开底栏。
  static const double height = 84;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flow = context.flowColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: flow.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _DockItem(
                    tab: tab,
                    selected: tab == selected,
                    onTap: () => onSelected(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.quick;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Tooltip(
        message: tab.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: motion,
              curve: AppMotion.curve,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    size: 22,
                    color: fg,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 仅首页翻页用：允许鼠标拖（全局行为去掉了 mouse，免得输入框选字拖页）。
class HomePageScrollBehavior extends ScrollBehavior {
  const HomePageScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}
