import 'package:flutter/material.dart';

abstract final class RoundsColors {
  static const ink = Color(0xFF172238);
  static const inkSecondary = Color(0xFF3D4A5D);
  static const muted = Color(0xFF748094);
  static const line = Color(0xFFE1E6EA);
  static const lineStrong = Color(0xFFCBD4DC);
  static const surface = Colors.white;
  static const canvas = Color(0xFFEEF2F4);
  static const orange = Color(0xFFFF6420);
  static const green = Color(0xFF168B50);
  static const greenSoft = Color(0xFFBDE9D4);
  static const red = Color(0xFFBF4A4A);
  static const warning = Color(0xFF9B5A00);
}

abstract final class RoundsSpace {
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class RoundsRadii {
  static const small = 7.0;
  static const surface = 10.0;
  static const large = 16.0;
}

abstract final class RoundsType {
  static const roadKicker = TextStyle(
    color: RoundsColors.orange,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: .85,
  );

  static const destination = TextStyle(
    color: RoundsColors.ink,
    fontSize: 22,
    height: 1.04,
    fontWeight: FontWeight.w800,
    letterSpacing: -.55,
  );

  static const destinationMeta = TextStyle(
    color: RoundsColors.muted,
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  static const navigationDistance = TextStyle(
    color: RoundsColors.ink,
    fontSize: 25,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -.8,
  );

  static const navigationDistanceMeta = TextStyle(
    color: RoundsColors.muted,
    fontSize: 12.5,
    height: 1,
    fontWeight: FontWeight.w700,
  );
}

ThemeData buildRoundsDriverTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: RoundsColors.ink,
    primary: RoundsColors.ink,
    secondary: RoundsColors.orange,
    surface: RoundsColors.surface,
    error: RoundsColors.red,
  );

  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: RoundsColors.canvas,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['Noto Sans Thai', 'sans-serif'],
    useMaterial3: true,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: RoundsColors.ink,
        fontSize: 31,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: -.9,
      ),
      titleLarge: TextStyle(
        color: RoundsColors.ink,
        fontSize: 22,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
      ),
      titleMedium: TextStyle(
        color: RoundsColors.ink,
        fontSize: 17,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: RoundsColors.inkSecondary,
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        color: RoundsColors.inkSecondary,
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontSize: 17,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RoundsRadii.small),
        ),
      ),
    ),
  );
}
