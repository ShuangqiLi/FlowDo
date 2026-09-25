import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 全局滚动风格：不画滚动条，内容放不下时直接拖着看，鼠标和触控笔也能拖。
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
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
