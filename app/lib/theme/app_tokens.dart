import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const double small = 8;
  static const double control = 12;
  static const double card = 12;
  static const double large = 20;
  static const double pill = 999;
}

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration celebration = Duration(milliseconds: 700);
  static const Curve curve = Curves.easeOutCubic;
}

abstract final class AppText {
  /// 思源黑体里的 U+2022（•）是全角字形，密码掩码点会被拉开近一倍。
  /// 字体里又没有窄一号的圆点可换，只能按字号收回这一段字距。
  static const double obscuringTighten = 0.44;

  /// 密码一类 `obscureText` 输入框的文字样式。只影响输入内容，标签不受牵连。
  static TextStyle obscuredStyle(TextStyle? base) {
    final fontSize = base?.fontSize ?? 16;
    return (base ?? const TextStyle()).copyWith(letterSpacing: -fontSize * obscuringTighten);
  }
}

abstract final class AppLayout {
  static const double contentMaxWidth = 760;
  static const double readingMaxWidth = 620;

  /// 桌面和网页用按钮操作任务；手机、平板用左右滑，不放按钮以免误触。
  static bool usesPointerActions(BuildContext context) {
    if (kIsWeb) {
      return true;
    }
    return switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
      _ => true,
    };
  }
}
