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
    onSurface: palette.onSurface,
    onSurfaceVariant: palette.onSurfaceVariant,
    outline: palette.outline.withValues(alpha: 0.9),
    outlineVariant: palette.outline,
    error: const Color(0xFFDC2626),
    onError: Colors.white,
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
    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
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
        highPriority: const Color(0xFFB86B6B),
        mediumPriority: const Color(0xFFC4895A),
        lowPriority: const Color(0xFF7A8694),
      ),
    ],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: palette.canvas,
      foregroundColor: palette.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: palette.onSurface,
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
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.85)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.primary, width: 1.7),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.65),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
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
        minimumSize: const Size(48, 48),
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
        minimumSize: const Size(44, 44),
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
      // 低饱和生产力色：保留色相，压低 chroma
      AppThemeKey.mint => const _Palette(
          primary: Color(0xFF5F9B82),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE3EEE7),
          onPrimaryContainer: Color(0xFF355244),
          secondary: Color(0xFF79A88C),
          secondaryContainer: Color(0xFFE6EEE8),
          canvas: Color(0xFFF4F7F4),
          card: Color(0xFFFFFFFF),
          softFill: Color(0xFFE6EEE8),
          outline: Color(0xFFC3D4C8),
          onSurface: Color(0xFF3A4A40),
          onSurfaceVariant: Color(0xFF66727A),
          success: Color(0xFF5F9B82),
        ),
      AppThemeKey.hazeBlue => const _Palette(
          primary: Color(0xFF5B82A8),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE2EAF3),
          onPrimaryContainer: Color(0xFF354A5C),
          secondary: Color(0xFF7396B5),
          secondaryContainer: Color(0xFFE6EEF4),
          canvas: Color(0xFFF3F6F9),
          card: Color(0xFFFFFFFF),
          softFill: Color(0xFFE6EEF4),
          outline: Color(0xFFC2D0DC),
          onSurface: Color(0xFF384A58),
          onSurfaceVariant: Color(0xFF66727A),
          success: Color(0xFF5F9B82),
        ),
      AppThemeKey.warmOrange => const _Palette(
          primary: Color(0xFFC4895A),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFF2EBE3),
          onPrimaryContainer: Color(0xFF5C4636),
          secondary: Color(0xFFD0A07A),
          secondaryContainer: Color(0xFFF3EEE8),
          canvas: Color(0xFFF7F4F0),
          card: Color(0xFFFFFFFF),
          softFill: Color(0xFFF2EBE3),
          outline: Color(0xFFDDD0C2),
          onSurface: Color(0xFF4A4038),
          onSurfaceVariant: Color(0xFF73685E),
          success: Color(0xFF5F9B82),
        ),
      AppThemeKey.lightPurple => const _Palette(
          primary: Color(0xFF8A7BA5),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFECE8F2),
          onPrimaryContainer: Color(0xFF4A4458),
          secondary: Color(0xFF9E91B5),
          secondaryContainer: Color(0xFFF1EEF5),
          canvas: Color(0xFFF6F5F8),
          card: Color(0xFFFFFFFF),
          softFill: Color(0xFFECE8F2),
          outline: Color(0xFFD4CEDC),
          onSurface: Color(0xFF443F4C),
          onSurfaceVariant: Color(0xFF66727A),
          success: Color(0xFF5F9B82),
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
    required this.onSurface,
    required this.onSurfaceVariant,
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
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color success;
}
