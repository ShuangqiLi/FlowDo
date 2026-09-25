import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 全局滚动风格：不画滚动条，边缘回弹，鼠标和触控笔也能拖。
class FlowDoScrollBehavior extends MaterialScrollBehavior {
  const FlowDoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // 全平台统一回弹；内容不满一屏也能跟手弹一下。
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
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
