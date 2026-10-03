import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/theme.dart';

void main() {
  test('all theme keys build distinct low-saturation themes', () {
    final themes = AppThemeKey.values.map(buildAppTheme).toList();
    expect(
      themes.map((theme) => theme.colorScheme.primary).toSet(),
      hasLength(AppThemeKey.values.length),
    );
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

  test('priority accents stay fixed and miss every theme primary', () {
    final themes = {
      for (final key in AppThemeKey.values) key: buildAppTheme(key),
    };
    final accents = [
      FlowDoPriorityPalette.high,
      FlowDoPriorityPalette.medium,
      FlowDoPriorityPalette.low,
      FlowDoPriorityPalette.none,
      FlowDoPriorityPalette.reminder,
    ];
    expect(accents.toSet(), hasLength(5));

    for (final theme in themes.values) {
      final colors = theme.extension<FlowDoColors>()!;
      expect(colors.priority('HIGH'), FlowDoPriorityPalette.high);
      expect(colors.priority('MEDIUM'), FlowDoPriorityPalette.medium);
      expect(colors.priority('LOW'), FlowDoPriorityPalette.low);
      expect(colors.priority('NONE'), FlowDoPriorityPalette.none);
      expect(colors.priority('REMINDER'), FlowDoPriorityPalette.reminder);
      for (final accent in accents) {
        expect(accent, isNot(theme.colorScheme.primary));
      }
    }

    expect(FlowDoPriorityPalette.medium, const Color(0xFFC4895A));
    expect(FlowDoPriorityPalette.reminder, const Color(0xFFC4A86C));
    expect(
      FlowDoPriorityPalette.medium,
      isNot(themes[AppThemeKey.warmOrange]!.colorScheme.primary),
    );
    expect(
      FlowDoPriorityPalette.low,
      isNot(themes[AppThemeKey.mint]!.colorScheme.primary),
    );
    expect(
      FlowDoPriorityPalette.low,
      isNot(themes[AppThemeKey.hazeBlue]!.colorScheme.primary),
    );
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
