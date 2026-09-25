import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr/theme.dart';

void main() {
  test('all four theme keys build distinct low-saturation themes', () {
    final themes = AppThemeKey.values.map(buildAppTheme).toList();
    expect(themes.map((theme) => theme.colorScheme.primary).toSet(), hasLength(4));
    for (final theme in themes) {
      expect(theme.extension<FlowDoColors>(), isNotNull);
      expect(
        _contrast(
          theme.colorScheme.onSurface,
          theme.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('unknown account theme falls back to mint', () {
    expect(AppThemeKey.fromKey('unknown'), AppThemeKey.mint);
    expect(AppThemeKey.fromKey(null), AppThemeKey.mint);
  });
}

double _contrast(Color a, Color b) {
  final light = a.computeLuminance();
  final dark = b.computeLuminance();
  final high = light > dark ? light : dark;
  final low = light > dark ? dark : light;
  return (high + 0.05) / (low + 0.05);
}
