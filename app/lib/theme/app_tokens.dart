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

abstract final class AppLayout {
  static const double contentMaxWidth = 760;
  static const double readingMaxWidth = 620;
}
