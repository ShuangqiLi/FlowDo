import 'package:flutter/material.dart';

import 'swipe_away.dart';

/// 子页路由：左缘右滑可退回，带跟手动画。
class FlowDoPageRoute<T> extends MaterialPageRoute<T> {
  FlowDoPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.swipeFromLeftEdgeOnly = true,
  }) : super(
          builder: (context) => SwipeToPop(
            fromLeftEdgeOnly: swipeFromLeftEdgeOnly,
            child: builder(context),
          ),
        );

  final bool swipeFromLeftEdgeOnly;
}
