import 'package:flutter/material.dart';
import '../components/motion.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

// Everything below is built from the tokens in colors.dart, spacing.dart and
// typography.dart. Screens import theme.dart to get all of them at once.
export 'colors.dart';
export 'spacing.dart';
export 'typography.dart';

ThemeData appTheme([Brightness brightness = Brightness.dark]) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    tertiary: AppColors.accent,
    error: AppColors.red,
    surface: p.surface,
    onSurface: p.text,
    surfaceContainerHighest: p.surfaceHigh,
    outline: p.line,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );
  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );

  final base = ThemeData(brightness: brightness, useMaterial3: true);
  // Large, bold headings; calm body text. Khmer and Latin in one family.
  final text = base.textTheme
      .copyWith(
        displaySmall: AppText.display,
        headlineMedium: AppText.headline,
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
      )
      .apply(
        fontFamily: appFontFamily,
        bodyColor: p.text,
        displayColor: p.text,
      );

  return base.copyWith(
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: p.page,
    canvasColor: p.page,
    splashFactory: InkSparkle.splashFactory,
    // Every page swings in in 3D (widgets/motion.dart)
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const Depth3DPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.page,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: p.text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: p.surfaceHigh,
        disabledForegroundColor: p.muted,
        minimumSize: const Size(64, 50),
        shape: rounded,
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.surfaceHigh,
        foregroundColor: p.text,
        minimumSize: const Size(64, 50),
        shape: rounded,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(64, 50),
        shape: rounded,
        side: BorderSide(color: p.glassEdge, width: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        shape: rounded,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: field(p.line),
      enabledBorder: field(p.line),
      focusedBorder: field(AppColors.accent, 1.6),
      errorBorder: field(AppColors.red),
      focusedErrorBorder: field(AppColors.red, 1.6),
      labelStyle: TextStyle(color: p.textSoft),
      hintStyle: TextStyle(color: p.muted),
      prefixIconColor: p.muted,
      suffixIconColor: p.muted,
    ),
    cardTheme: CardThemeData(
      color: p.glass,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        side: BorderSide(color: p.glassEdge),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        side: BorderSide(color: p.glassEdge),
      ),
      titleTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: p.text,
      ),
      contentTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 15,
        height: 1.5,
        color: p.textSoft,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: p.glassEdge),
      backgroundColor: p.glass,
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontFamily: appFontFamily,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceHigh,
      contentTextStyle: TextStyle(color: p.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      iconColor: p.textSoft,
      textColor: p.text,
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: p.glassEdge),
      ),
      textStyle: TextStyle(color: p.text),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.accent,
      textColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : p.surfaceHigh,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accent : null,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accent : p.muted,
      ),
    ),
  );
}
