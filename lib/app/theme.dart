import 'package:flutter/material.dart';

/// Default soft palette from CLAUDE.md.
abstract final class Palette {
  static const sky = Color(0xFFCBF0F8);
  static const blue = Color(0xFFAECBFA);
  static const lilac = Color(0xFFD7AEFB);
  static const pink = Color(0xFFFDCFE8);

  // Gentle amount colours. Measured ≥ 5.2:1 on white and on [sky]; see
  // .claude/skills/tracks-design before changing them.
  static const income = Color(0xFF276B4E);
  static const expense = Color(0xFF9E3F5E);
  static const incomeDark = Color(0xFF8FD8B4);
  static const expenseDark = Color(0xFFF4A7C0);
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  var scheme = ColorScheme.fromSeed(
    seedColor: Palette.blue,
    brightness: brightness,
  );
  if (light) {
    scheme = scheme.copyWith(
      primaryContainer: Palette.blue,
      secondaryContainer: Palette.sky,
      tertiaryContainer: Palette.lilac,
      surfaceContainerLow: const Color(0xFFF5FBFD),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    chipTheme: const ChipThemeData(showCheckmark: false),
  );
}

extension AmountColors on ThemeData {
  Color get incomeColor =>
      brightness == Brightness.light ? Palette.income : Palette.incomeDark;
  Color get expenseColor =>
      brightness == Brightness.light ? Palette.expense : Palette.expenseDark;
}
