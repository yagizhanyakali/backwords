import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF0A0A12);
  static const surface = Color(0xFF16161F);
  static const surfaceHigh = Color(0xFF242432);
  static const pink = Color(0xFFFF3D81);
  static const lime = Color(0xFFC8FF3D);
  static const cyan = Color(0xFF3DE0FF);
  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFB4B4C8);
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.pink,
    onPrimary: Colors.black,
    secondary: AppColors.lime,
    onSecondary: Colors.black,
    tertiary: AppColors.cyan,
    onTertiary: Colors.black,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceHigh,
    error: Color(0xFFFF6B6B),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.textDim, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.lime,
      inactiveTrackColor: AppColors.surfaceHigh,
      thumbColor: AppColors.lime,
      overlayColor: Color(0x33C8FF3D),
      trackHeight: 6,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDim,
        selectedBackgroundColor: AppColors.cyan,
        selectedForegroundColor: Colors.black,
        side: const BorderSide(color: AppColors.surfaceHigh),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
  );
}
