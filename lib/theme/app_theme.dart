/// AppTheme — Raketa design system
/// Syne (display) + DM Sans (body), brand color palette
library app_theme;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
class AppColors {
  // Brand
  static const violet     = Color(0xFF7C3AED);
  static const violetDark = Color(0xFF6D28D9);
  static const violetA    = Color(0x1A7C3AED);
  static const lime       = Color(0xFF84CC16);
  static const limeA      = Color(0x1F84CC16);
  static const limeDark   = Color(0xFF65A30D);
  static const limeText   = Color(0xFF3F6212);
  static const orange     = Color(0xFFF97316);
  static const orangeDark = Color(0xFFEA6C0A);
  static const orangeA    = Color(0x1AF97316);
  static const red        = Color(0xFFEF4444);
  static const skyA       = Color(0x140EA5E9);
  static const skyBorder  = Color(0x330EA5E9);

  // Light surfaces
  static const lightBg        = Color(0xFFF1F5F9);
  static const lightSurface   = Color(0xFFFFFFFF);
  static const lightSurfaceHi = Color(0xFFEEF2F7);
  static const lightDivider   = Color(0xFFE2E8F0);
  static const lightBorder    = Color(0x1A0F172A);
  static const lightBorderXs  = Color(0x0D0F172A);
  static const lightT1        = Color(0xFF0F172A);
  static const lightT2        = Color(0xFF475569);
  static const lightT3        = Color(0xFF94A3B8);

  // Dark surfaces
  static const darkBg        = Color(0xFF0D1117);
  static const darkSurface   = Color(0xFF161B22);
  static const darkSurfaceHi = Color(0xFF21262D);
  static const darkDivider   = Color(0xFF30363D);
  static const darkBorder    = Color(0xFF30363D);
  static const darkBorderXs  = Color(0xFF21262D);
  static const darkT1        = Color(0xFFF0F6FF);
  static const darkT2        = Color(0xFF8B949E);
  static const darkT3        = Color(0xFF484F58);
}

// ─── Typography ───────────────────────────────────────────────────────────────
class AppFonts {
  // Cache font families to avoid repeated object construction
  static final String _display = GoogleFonts.syne().fontFamily!;
  static final String _body    = GoogleFonts.dmSans().fontFamily!;

  static String get displayFamily => _display;
  static String get bodyFamily    => _body;

  // Syne — headings
  static TextStyle logo(Color c)         => TextStyle(fontFamily: _display, fontSize: 19, fontWeight: FontWeight.w800, color: c);
  static TextStyle heading(Color c)      => TextStyle(fontFamily: _display, fontSize: 16, fontWeight: FontWeight.w800, color: c);
  static TextStyle cardHeadline(Color c) => TextStyle(fontFamily: _display, fontSize: 14, fontWeight: FontWeight.w700, color: c);
  static TextStyle statLarge(Color c)    => TextStyle(fontFamily: _display, fontSize: 34, fontWeight: FontWeight.w800, color: c, height: 1.0);
  static TextStyle verdict(Color c)      => TextStyle(fontFamily: _display, fontSize: 16, fontWeight: FontWeight.w800, color: c);
  static TextStyle navStep(Color c)      => TextStyle(fontFamily: _display, fontSize: 9,  fontWeight: FontWeight.w800, color: c);

  // DM Sans — body
  static TextStyle body(Color c, {double size = 14})       => TextStyle(fontFamily: _body, fontSize: size, fontWeight: FontWeight.w400, color: c, height: 1.5);
  static TextStyle bodyMedium(Color c, {double size = 14}) => TextStyle(fontFamily: _body, fontSize: size, fontWeight: FontWeight.w500, color: c, height: 1.5);
  static TextStyle btnPrimary(Color c)   => TextStyle(fontFamily: _body, fontSize: 15, fontWeight: FontWeight.w700, color: c);
  static TextStyle btnGhost(Color c)     => TextStyle(fontFamily: _body, fontSize: 12, fontWeight: FontWeight.w600, color: c);
  static TextStyle fieldLabel(Color c)   => TextStyle(fontFamily: _body, fontSize: 10, fontWeight: FontWeight.w700, color: c, letterSpacing: 0.7);
  static TextStyle caption(Color c)      => TextStyle(fontFamily: _body, fontSize: 12, fontWeight: FontWeight.w400, color: c);
  static TextStyle micro(Color c)        => TextStyle(fontFamily: _body, fontSize: 10, fontWeight: FontWeight.w700, color: c);
}

// ─── ThemeData factories ──────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData light({PageTransitionsTheme? pageTransitions}) => _build(
        cs: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.violet,
          onPrimary: Colors.white,
          primaryContainer: AppColors.violetA,
          onPrimaryContainer: AppColors.violet,
          secondary: AppColors.lime,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.limeA,
          onSecondaryContainer: AppColors.limeText,
          tertiary: AppColors.orange,
          onTertiary: Colors.white,
          tertiaryContainer: AppColors.orangeA,
          onTertiaryContainer: AppColors.orangeDark,
          error: AppColors.red,
          onError: Colors.white,
          errorContainer: Color(0xFFFFDAD6),
          onErrorContainer: Color(0xFF410002),
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightT1,
          surfaceContainerHighest: AppColors.lightSurfaceHi,
          onSurfaceVariant: AppColors.lightT2,
          outline: AppColors.lightBorder,
          outlineVariant: AppColors.lightBorderXs,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: AppColors.darkSurface,
          onInverseSurface: AppColors.darkT1,
          inversePrimary: AppColors.violetA,
        ),
        bg: AppColors.lightBg,
        bodyColor: AppColors.lightT1,
        pageTransitions: pageTransitions,
      );

  static ThemeData dark({PageTransitionsTheme? pageTransitions}) => _build(
        cs: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.violet,
          onPrimary: Colors.white,
          primaryContainer: AppColors.violetA,
          onPrimaryContainer: Color(0xFFD9C6FF),
          secondary: AppColors.lime,
          onSecondary: AppColors.limeText,
          secondaryContainer: AppColors.limeA,
          onSecondaryContainer: AppColors.lime,
          tertiary: AppColors.orange,
          onTertiary: Colors.white,
          tertiaryContainer: AppColors.orangeA,
          onTertiaryContainer: AppColors.orange,
          error: AppColors.red,
          onError: Colors.white,
          errorContainer: Color(0xFF8C0009),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkT1,
          surfaceContainerHighest: AppColors.darkSurfaceHi,
          onSurfaceVariant: AppColors.darkT2,
          outline: AppColors.darkBorder,
          outlineVariant: AppColors.darkBorderXs,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: AppColors.lightSurface,
          onInverseSurface: AppColors.lightT1,
          inversePrimary: AppColors.violet,
        ),
        bg: AppColors.darkBg,
        bodyColor: AppColors.darkT1,
        pageTransitions: pageTransitions,
      );

  static ThemeData _build({
    required ColorScheme cs,
    required Color bg,
    required Color bodyColor,
    PageTransitionsTheme? pageTransitions,
  }) {
    final body = AppFonts.bodyFamily;
    final disp = AppFonts.displayFamily;
    final base = GoogleFonts.dmSansTextTheme()
        .apply(bodyColor: bodyColor, displayColor: bodyColor);

    return ThemeData(
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      textTheme: base,
      useMaterial3: true,
      pageTransitionsTheme: pageTransitions ??
          const PageTransitionsTheme(builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          }),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
            fontFamily: disp, fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        labelStyle: TextStyle(
            fontFamily: body, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.7),
        hintStyle: TextStyle(fontFamily: body, color: cs.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          textStyle: TextStyle(fontFamily: body, fontSize: 15, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          textStyle: TextStyle(fontFamily: body, fontSize: 12, fontWeight: FontWeight.w600),
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      ),
      dividerTheme: DividerThemeData(
          color: cs.outlineVariant, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
            fontFamily: body, fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface),
        subtitleTextStyle: TextStyle(
            fontFamily: body, fontSize: 12, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ─── BuildContext helpers ─────────────────────────────────────────────────────
extension BuildContextThemeX on BuildContext {
  bool  get isDark   => Theme.of(this).brightness == Brightness.dark;
  Color get bg       => isDark ? AppColors.darkBg        : AppColors.lightBg;
  Color get surf     => isDark ? AppColors.darkSurface   : AppColors.lightSurface;
  Color get surfHi   => isDark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi;
  Color get divider  => isDark ? AppColors.darkDivider   : AppColors.lightDivider;
  Color get border   => isDark ? AppColors.darkBorder    : AppColors.lightBorder;
  Color get textPri  => isDark ? AppColors.darkT1        : AppColors.lightT1;
  Color get textSec  => isDark ? AppColors.darkT2        : AppColors.lightT2;
  Color get textTer  => isDark ? AppColors.darkT3        : AppColors.lightT3;
  TextTheme get textTheme => Theme.of(this).textTheme;
}

// ─── Card decoration helper ───────────────────────────────────────────────────
class GlassDecoration {
  static BoxDecoration card({required bool isDark, double radius = 14}) =>
      BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      );
}
