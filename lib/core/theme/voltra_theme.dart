import 'package:flutter/material.dart';

import 'voltra_palette.dart';

export 'voltra_palette.dart';

/// Builds the app-wide [ThemeData] from a [VoltraPalette].
///
/// One place decides how VOLTRA looks. Screens read colours from
/// `context.palette` and text styles from `Theme.of(context).textTheme`, so a
/// context change repaints everything consistently.
class VoltraTheme {
  const VoltraTheme._();

  static ThemeData build(VoltraPalette p) {
    // MORNING is a light palette, so the scheme has to follow it. Getting this
    // wrong is what makes Material paint white-on-white ripples and tooltips.
    final scheme = p.isLight
        ? ColorScheme.light(
            primary: p.accent,
            onPrimary: p.onAccent,
            secondary: p.accent,
            onSecondary: p.onAccent,
            surface: p.surface,
            onSurface: p.textPrimary,
            error: p.danger,
            onError: p.onAccent,
          )
        : ColorScheme.dark(
            primary: p.accent,
            onPrimary: p.onAccent,
            secondary: p.accent,
            onSecondary: p.onAccent,
            surface: p.surface,
            onSurface: p.textPrimary,
            error: p.danger,
            onError: p.onAccent,
          );

    final text = TextTheme(
      displaySmall: TextStyle(
        color: p.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        color: p.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: p.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: p.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.45),
      bodySmall: TextStyle(color: p.textMuted, fontSize: 12, height: 1.4),
      labelSmall: TextStyle(
        color: p.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
      textTheme: text,
      iconTheme: IconThemeData(color: p.textSecondary, size: 20),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: p.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textSecondary),
        helperStyle: TextStyle(color: p.textMuted, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.accent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[p],
    );
  }
}
