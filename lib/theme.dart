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

double dialogWidth(BuildContext context, double max) =>
    (MediaQuery.of(context).size.width - 48).clamp(0, max).toDouble();

Widget highlightCard(BuildContext context, {required Widget child}) {
  if (Theme.of(context).brightness == Brightness.dark) return Card(child: child);
  return Card(
    color: lightHighlightTint,
    shape: const RoundedRectangleBorder(borderRadius: borderRadiusLg, side: BorderSide(color: lightHighlightBorder)),
    child: child,
  );
}

TextStyle unboundedStyle({required FontWeight weight, double? letterSpacing, Color? color}) {
  return TextStyle(fontFamily: 'Unbounded', fontWeight: weight, letterSpacing: letterSpacing, color: color);
}

const lightDivider = Color(0xFFE8E3DC);
const lightSubtleFill = Color(0xFFF4F1EC);
const lightHint = Color(0xFF6B6965);
const lightSelectedTint = Color(0x29FD7E14);
const lightHighlightTint = Color(0xFFFFF4E6);
const lightHighlightBorder = Color(0xFFFFD8A8);

ThemeData buildLightTheme() {
  final textTheme = ThemeData.light().textTheme.apply(fontFamily: 'Manrope');
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryLight,
      brightness: Brightness.light,
      primary: primaryLight,
      surface: Colors.white,
    ),
    textTheme: textTheme,
    hintColor: lightHint,
    dividerColor: lightDivider,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.black,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: borderRadiusLg, side: const BorderSide(color: lightDivider)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSubtleFill,
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: const BorderSide(color: lightDivider),
        shape: const RoundedRectangleBorder(borderRadius: borderRadiusLg),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: lightSubtleFill,
      selectedColor: lightSelectedTint,
      disabledColor: lightSubtleFill,
      labelStyle: const TextStyle(color: Colors.black87),
      secondaryLabelStyle: const TextStyle(color: primaryDark, fontWeight: FontWeight.w600),
      checkmarkColor: primaryDark,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? lightSelectedTint : Colors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primaryDark : Colors.black87,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: lightDivider)),
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
