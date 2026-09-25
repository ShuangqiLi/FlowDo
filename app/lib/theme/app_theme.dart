import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_tokens.dart';

ThemeData buildAppTheme([AppThemeKey themeKey = AppThemeKey.mint]) {
  final palette = _palette(themeKey);
  final generated = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: Brightness.light,
  );
  final scheme = generated.copyWith(
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    primaryContainer: palette.primaryContainer,
    onPrimaryContainer: palette.onPrimaryContainer,
    secondary: palette.secondary,
    secondaryContainer: palette.secondaryContainer,
    surface: palette.card,
    onSurface: const Color(0xFF29332E),
    onSurfaceVariant: const Color(0xFF65716B),
    outline: const Color(0xFF909C96),
    outlineVariant: palette.outline,
  );

  final baseText = Typography.material2021().black.apply(
        fontFamily: 'NotoSansSC',
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
  final textTheme = baseText.copyWith(
    displaySmall: baseText.displaySmall?.copyWith(
      fontFamily: 'ZCOOLKuaiLe',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontFamily: 'ZCOOLKuaiLe',
      fontWeight: FontWeight.w400,
    ),
    headlineSmall: baseText.headlineSmall?.copyWith(
      fontFamily: 'ZCOOLKuaiLe',
      fontWeight: FontWeight.w400,
    ),
    titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: baseText.bodyLarge?.copyWith(height: 1.55),
    bodyMedium: baseText.bodyMedium?.copyWith(height: 1.5),
    bodySmall: baseText.bodySmall?.copyWith(height: 1.45),
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.card),
    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'NotoSansSC',
    textTheme: textTheme,
    scaffoldBackgroundColor: palette.canvas,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    extensions: [
      FlowDoColors(
        canvas: palette.canvas,
        card: palette.card,
        softFill: palette.softFill,
        success: palette.success,
        highPriority: const Color(0xFFB96F72),
        mediumPriority: const Color(0xFFC18D55),
        lowPriority: const Color(0xFF738D9D),
      ),
    ],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: palette.canvas,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: palette.card.withValues(alpha: 0.97),
      elevation: 0,
      indicatorColor: palette.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 15,
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.primary, width: 1.7),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0.8,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 15,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: textTheme.labelMedium,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    ),
  );
}

_Palette _palette(AppThemeKey key) => switch (key) {
      AppThemeKey.mint => const _Palette(
          primary: Color(0xFF4F8F70),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE8F5EE),
          onPrimaryContainer: Color(0xFF285641),
          secondary: Color(0xFF728E81),
          secondaryContainer: Color(0xFFE9F0EC),
          canvas: Color(0xFFF6F9F7),
          card: Color(0xFFFCFEFD),
          softFill: Color(0xFFF0F6F3),
          outline: Color(0xFFD9E5DE),
          success: Color(0xFF5E9A79),
        ),
      AppThemeKey.hazeBlue => const _Palette(
          primary: Color(0xFF5E7F99),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE8F0F6),
          onPrimaryContainer: Color(0xFF334F65),
          secondary: Color(0xFF798995),
          secondaryContainer: Color(0xFFEBEFF2),
          canvas: Color(0xFFF5F8FA),
          card: Color(0xFFFCFDFE),
          softFill: Color(0xFFEEF3F6),
          outline: Color(0xFFD8E1E7),
          success: Color(0xFF6B9385),
        ),
      AppThemeKey.warmOrange => const _Palette(
          primary: Color(0xFFA86F43),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFF8EDE3),
          onPrimaryContainer: Color(0xFF674326),
          secondary: Color(0xFF927D6C),
          secondaryContainer: Color(0xFFF1ECE7),
          canvas: Color(0xFFFAF7F3),
          card: Color(0xFFFFFDFC),
          softFill: Color(0xFFF6F0EA),
          outline: Color(0xFFE9DDD2),
          success: Color(0xFF72917A),
        ),
      AppThemeKey.lightPurple => const _Palette(
          primary: Color(0xFF78679B),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFF0EBF7),
          onPrimaryContainer: Color(0xFF4C3E6A),
          secondary: Color(0xFF887F95),
          secondaryContainer: Color(0xFFF0EDF3),
          canvas: Color(0xFFF8F6FA),
          card: Color(0xFFFEFDFE),
          softFill: Color(0xFFF3EFF6),
          outline: Color(0xFFE4DDEB),
          success: Color(0xFF708F80),
        ),
    };

class _Palette {
  const _Palette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.canvas,
    required this.card,
    required this.softFill,
    required this.outline,
    required this.success,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color canvas;
  final Color card;
  final Color softFill;
  final Color outline;
  final Color success;
}
