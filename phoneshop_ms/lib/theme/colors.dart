import 'package:flutter/material.dart';
import 'spacing.dart';

// The PS168 look in one place, in two moods the customer can switch between
// (☀️ / 🌙, lib/services/theme_mode.dart):
//  - Dark: premium and minimal (Apple Store app / Nothing): a near-black page,
//    frosted-glass cards.
//  - Light: the same layout on a soft white page with white cards.
// Both share ONE accent colour (electric blue), 24px corners and big bold
// headings. Every screen, store and admin, takes its colours from here.

// One set of colours for one mode
class AppPalette {
  final Brightness brightness;
  final Color page, surface, surfaceHigh, tileLow, tileLower;
  final Color glass, glassStrong, glassEdge, line, outline;
  final Color text, text2, text3, textSoft, muted;
  final Color shadow, shadowStrong;

  const AppPalette({
    required this.brightness,
    required this.page,
    required this.surface,
    required this.surfaceHigh,
    required this.tileLow,
    required this.tileLower,
    required this.glass,
    required this.glassStrong,
    required this.glassEdge,
    required this.line,
    required this.outline,
    required this.text,
    required this.text2,
    required this.text3,
    required this.textSoft,
    required this.muted,
    required this.shadow,
    required this.shadowStrong,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF0A0A0A), // near-black background
    surface: Color(0xFF141416), // solid card / sheet
    surfaceHigh: Color(0xFF1C1C1F), // fields, raised tiles
    tileLow: Color(0xFF121214),
    tileLower: Color(0xFF101012),
    glass: Color(0x14FFFFFF), // 8% white veil
    glassStrong: Color(0x1FFFFFFF),
    glassEdge: Color(0x24FFFFFF), // hairline edge
    line: Color(0xFF2A2A2E), // dividers
    outline: Color(0xFF3A3A3F),
    text: Color(0xFFF5F5F7), // primary text
    text2: Color(0xFFE5E5EA),
    text3: Color(0xFFD1D1D6),
    textSoft: Color(0xFFC7C7CC), // secondary text
    muted: Color(0xFF8E8E93), // hints, captions
    shadow: Color(0x66000000),
    shadowStrong: Color(0x99000000),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    page: Color(0xFFF3F5F9), // soft white background
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1F4F8),
    tileLow: Color(0xFFEEF2F7),
    tileLower: Color(0xFFE8EDF4),
    glass: Color(0xFFFFFFFF), // white cards
    glassStrong: Color(0xFFFFFFFF),
    glassEdge: Color(0x140F172A), // hairline edge
    line: Color(0xFFE3E8EF),
    outline: Color(0xFFCBD5E1),
    text: Color(0xFF0F172A),
    text2: Color(0xFF1E293B),
    text3: Color(0xFF334155),
    textSoft: Color(0xFF475569),
    muted: Color(0xFF64748B),
    shadow: Color(0x1A0F172A),
    shadowStrong: Color(0x290F172A),
  );
}

// The colours of the mode in use. Screens read these while they build, and
// the whole app is rebuilt when the mode changes, so they always match.
class AppColors {
  static AppPalette current = AppPalette.dark;
  static bool get isDark => current.brightness == Brightness.dark;

  static Color get page => current.page;
  static Color get surface => current.surface;
  static Color get surfaceHigh => current.surfaceHigh;
  static Color get tileLow => current.tileLow;
  static Color get tileLower => current.tileLower;
  static Color get glass => current.glass;
  static Color get glassStrong => current.glassStrong;
  static Color get glassEdge => current.glassEdge;
  static Color get line => current.line;
  static Color get outline => current.outline;
  static Color get text => current.text;
  static Color get text2 => current.text2;
  static Color get text3 => current.text3;
  static Color get textSoft => current.textSoft;
  static Color get muted => current.muted;
  static Color get shadow => current.shadow;
  static Color get shadowStrong => current.shadowStrong;

  // The same in both modes
  static const accent = Color(0xFF3D7BFF); // electric blue, the one accent
  static const accentDeep = Color(0xFF2F62D9); // pressed / gradient end
  // Meaning only (never decoration): sale / error, success, warning
  static const red = Color(0xFFFF453A);
  static const green = Color(0xFF30D158);
  static const amber = Color(0xFFFFD60A);

  // Kept for older code that still says navy / teal / orange
  static Color get navy => text;
  static const teal = accent;
  static const orange = accent;
}

// A frosted-glass panel: translucent fill, hairline edge, 24px corners.
BoxDecoration glassDecoration({
  double radius = AppRadius.xxl,
  Color? fill,
  bool shadow = true,
}) => BoxDecoration(
  color: fill ?? AppColors.glass,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.glassEdge),
  boxShadow: shadow
      ? [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ]
      : null,
);
