import 'package:flutter/material.dart';

import '../theme.dart';

/// 悬浮胶囊底栏：任务池 / 聚焦 / 完成三等分。
/// 选中态是包住图标和文字的浅色药丸。
class FocusDock extends StatelessWidget {
  const FocusDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 不含底部安全区。FAB 用它躲开底栏。
  static const double height = 84;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flow = context.flowColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + bottomInset),
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
              Expanded(
                child: _DockItem(
                  selected: selectedIndex == 0,
                  icon: Icons.inbox_outlined,
                  selectedIcon: Icons.inbox_rounded,
                  label: '任务池',
                  onTap: () => onSelected(0),
                ),
              ),
              Expanded(
                child: _DockItem(
                  selected: selectedIndex == 1,
                  icon: Icons.center_focus_strong_outlined,
                  selectedIcon: Icons.center_focus_strong_rounded,
                  label: '聚焦',
                  onTap: () => onSelected(1),
                ),
              ),
              Expanded(
                child: _DockItem(
                  selected: selectedIndex == 2,
                  icon: Icons.check_circle_outline_rounded,
                  selectedIcon: Icons.check_circle_rounded,
                  label: '完成',
                  onTap: () => onSelected(2),
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
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.quick;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;

    return SizedBox.expand(
      child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: motion,
              curve: AppMotion.curve,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? selectedIcon : icon, size: 22, color: fg),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: fg,
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
