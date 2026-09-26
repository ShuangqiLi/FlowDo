import 'package:flutter/material.dart';

import '../theme.dart';

/// 底栏：任务池 / 聚焦 / 完成 三等分平铺，聚焦占 C 位。
///
/// 选中态只落在图标上：两侧是图标背后的小药丸，中间是放大的圆形按钮；文字不参与任何框选。
class FocusDock extends StatelessWidget {
  const FocusDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 不含底部安全区的高度，FAB 用它算可活动范围。
  static const double height = 80;

  /// 聚焦圆按钮的直径。
  static const double focusButtonSize = 54;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flow = context.flowColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: flow.card,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SideItem(
                    selected: selectedIndex == 0,
                    icon: Icons.inbox_outlined,
                    selectedIcon: Icons.inbox_rounded,
                    label: '任务池',
                    onTap: () => onSelected(0),
                  ),
                ),
                Expanded(
                  child: _FocusItem(
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                ),
                Expanded(
                  child: _SideItem(
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
      ),
    );
  }
}

Duration _motion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.standard;

TextStyle _labelStyle(
  BuildContext context, {
  required Color color,
  required bool selected,
}) {
  return Theme.of(context).textTheme.labelSmall!.copyWith(
        color: color,
        fontSize: 12,
        height: 1.1,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      );
}

/// 两侧的普通页签：选中时只在图标背后垫一枚药丸，文字保持原样。
class _SideItem extends StatelessWidget {
  const _SideItem({
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
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;
    final motion = _motion(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          // 反馈只落在图标附近，不要整块矩形的悬停底色。
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          radius: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: motion,
                curve: AppMotion.curve,
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? scheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                alignment: Alignment.center,
                child: Icon(selected ? selectedIcon : icon, size: 24, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle(context, color: fg, selected: selected),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// 中间的聚焦：一颗放大的圆形按钮，平时是浅底描边，选中后填满主色并微微放大。
class _FocusItem extends StatelessWidget {
  const _FocusItem({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  static const String label = '聚焦';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = _motion(context);
    final fg = selected ? scheme.onPrimary : scheme.primary;
    final labelColor = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          radius: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedScale(
                scale: selected ? 1.0 : 0.9,
                duration: motion,
                curve: AppMotion.curve,
                child: AnimatedContainer(
                  duration: motion,
                  curve: AppMotion.curve,
                  width: FocusDock.focusButtonSize,
                  height: FocusDock.focusButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? scheme.primary : scheme.primaryContainer,
                    border: Border.all(
                      color: selected
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.35),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.32),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : const [],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    size: 30,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: _labelStyle(
                  context,
                  color: labelColor,
                  selected: selected,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
