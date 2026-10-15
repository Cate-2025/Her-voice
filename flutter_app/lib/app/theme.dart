import 'package:flutter/material.dart';

abstract final class VoiceColors {
  static const paper = Color(0xFFF8F6F2);
  static const ink = Color(0xFF302B35);
  static const muted = Color(0xFF696271);
  static const plum = Color(0xFF654A69);
  static const lavender = Color(0xFFEDE6EF);
  static const sage = Color(0xFFE6EDE5);
  static const green = Color(0xFF45674E);
  static const peach = Color(0xFFF3E5D8);
  static const line = Color(0xFFE5DFE5);
}

ThemeData voiceTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: VoiceColors.plum).copyWith(
      primary: VoiceColors.plum,
      surface: VoiceColors.paper,
      onSurface: VoiceColors.ink,
      outline: VoiceColors.line,
    ),
    scaffoldBackgroundColor: VoiceColors.paper,
    fontFamily: 'Manrope',
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: VoiceColors.ink, displayColor: VoiceColors.ink)
        .copyWith(
          displaySmall: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 38,
            height: 1.25,
            color: VoiceColors.ink,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 28,
            height: 1.3,
            color: VoiceColors.ink,
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 23,
            height: 1.35,
            color: VoiceColors.ink,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            height: 1.65,
            color: VoiceColors.ink,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            height: 1.6,
            color: VoiceColors.ink,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        side: const BorderSide(color: VoiceColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: VoiceColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: VoiceColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: VoiceColors.plum, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(color: VoiceColors.line, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
