import 'package:flutter/material.dart';

const orangeSwatch = [
  Color(0xFFFFF4E6),
  Color(0xFFFFE8CC),
  Color(0xFFFFD8A8),
  Color(0xFFFFC078),
  Color(0xFFFFA94D),
  Color(0xFFFF922B),
  Color(0xFFFD7E14),
  Color(0xFFF76707),
  Color(0xFFE8590C),
  Color(0xFFD9480F),
];

const primaryLight = Color(0xFFFD7E14);
const primaryDark = Color(0xFFE8590C);

const darkSurfaces = [
  Color(0xFFC9C7C3),
  Color(0xFFABA9A4),
  Color(0xFF8F8D88),
  Color(0xFF6B6965),
  Color(0xFF4A4844),
  Color(0xFF3A3835),
  Color(0xFF2E2C2A),
  Color(0xFF242220),
  Color(0xFF1B1A18),
  Color(0xFF131211),
];

const radiusLg = Radius.circular(16);
const borderRadiusLg = BorderRadius.all(radiusLg);

Color hexColor(String hex) => Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

TextStyle unboundedStyle({required FontWeight weight, double? letterSpacing, Color? color}) {
  return TextStyle(fontFamily: 'Unbounded', fontWeight: weight, letterSpacing: letterSpacing, color: color);
}

ThemeData buildLightTheme() {
  final textTheme = ThemeData.light().textTheme.apply(fontFamily: 'Manrope');
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F1E6),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryLight,
      brightness: Brightness.light,
      primary: primaryLight,
      surface: Colors.white,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.black,
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.62),
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: borderRadiusLg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.04),
      border: OutlineInputBorder(borderRadius: borderRadiusLg, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadiusLg,
        borderSide: const BorderSide(color: primaryLight, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: borderRadiusLg),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark().textTheme.apply(fontFamily: 'Manrope');
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkSurfaces[9],
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryDark,
      brightness: Brightness.dark,
      primary: primaryDark,
      surface: darkSurfaces[7],
    ),
    textTheme: base.apply(bodyColor: darkSurfaces[0], displayColor: darkSurfaces[0]),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: darkSurfaces[7].withValues(alpha: 0.6),
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: borderRadiusLg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(borderRadius: borderRadiusLg, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadiusLg,
        borderSide: const BorderSide(color: primaryDark, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: borderRadiusLg),
      ),
    ),
  );
}
