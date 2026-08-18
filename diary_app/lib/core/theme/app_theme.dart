import 'package:flutter/material.dart';

import 'theme_config.dart';

class AppColors {
  AppColors._();

  static const happy = Color(0xFF4ADE80);
  static const sad = Color(0xFF818CF8);
  static const angry = Color(0xFFF87171);
  static const calm = Color(0xFF2DD4BF);
  static const anxious = Color(0xFFFBBF24);
  static const neutral = Color(0xFF94A3B8);

  static Color moodColor(String mood) => switch (mood) {
        'happy' => happy,
        'sad' => sad,
        'angry' => angry,
        'calm' => calm,
        'anxious' => anxious,
        _ => neutral,
      };
}

class AppTheme {
  AppTheme._();

  static ThemeData fromPrefs(ThemePreferences prefs, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: prefs.accentColor.color,
      brightness: brightness,
    );

    final baseTextStyle = TextStyle(
      fontSize: prefs.fontSize.size,
      height: prefs.spacing.lineHeight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
      ),
      textTheme: TextTheme(
        displayLarge: baseTextStyle.copyWith(fontSize: 57, fontWeight: FontWeight.w300),
        displayMedium: baseTextStyle.copyWith(fontSize: 45, fontWeight: FontWeight.w400),
        displaySmall: baseTextStyle.copyWith(fontSize: 36, fontWeight: FontWeight.w400),
        headlineLarge: baseTextStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w600),
        headlineMedium: baseTextStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: baseTextStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: baseTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w500),
        titleMedium: baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall: baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: baseTextStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData light = fromPrefs(const ThemePreferences(), Brightness.light);
  static ThemeData dark = fromPrefs(const ThemePreferences(), Brightness.dark);
}
