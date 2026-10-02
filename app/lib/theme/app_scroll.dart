import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 列表下拉刷新用：内容不满一屏也能拉动，并且能产生回弹。
const refreshScrollPhysics = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);

/// 全局滚动风格：不画滚动条，边缘回弹，鼠标和触控笔也能拖。
class FlowDoScrollBehavior extends MaterialScrollBehavior {
  const FlowDoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // 全平台统一回弹；内容不满一屏也能跟手弹一下。
    return refreshScrollPhysics;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
