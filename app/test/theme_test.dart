import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/theme.dart';

void main() {
  test('all four theme keys build distinct low-saturation themes', () {
    final themes = AppThemeKey.values.map(buildAppTheme).toList();
    expect(
        themes.map((theme) => theme.colorScheme.primary).toSet(), hasLength(4));
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

  test('none and reminder accents follow the theme', () {
    final mint = buildAppTheme(AppThemeKey.mint);
    final haze = buildAppTheme(AppThemeKey.hazeBlue);
    final mintColors = mint.extension<FlowDoColors>()!;
    final hazeColors = haze.extension<FlowDoColors>()!;
    expect(mintColors.priority('NONE'), mint.colorScheme.primary);
    expect(mintColors.priority('REMINDER'), mint.colorScheme.primary);
    expect(hazeColors.priority('NONE'), haze.colorScheme.primary);
    expect(mintColors.priority('NONE'), isNot(hazeColors.priority('NONE')));
    expect(mintColors.priority('HIGH'), isNot(mint.colorScheme.primary));
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
