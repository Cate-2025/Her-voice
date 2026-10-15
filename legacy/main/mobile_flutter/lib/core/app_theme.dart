import 'package:flutter/material.dart';

/// Brand palette carried over from the original Android prototype
/// (mobile/app/src/main/res/values/colors.xml) so the Flutter client keeps the
/// same visual identity described in the concept paper.
class HerVoiceColors {
  const HerVoiceColors._();

  static const Color pinkPrimary = Color(0xFFE91E63);
  static const Color pinkPrimaryDark = Color(0xFFC2185B);
  static const Color pinkAccent = Color(0xFFFF4081);
  static const Color pinkLight = Color(0xFFFCE4EC);
  static const Color pinkMedium = Color(0xFFF8BBD0);
  static const Color backgroundTop = Color(0xFFFFF0F5);
  static const Color backgroundBottom = Color(0xFFFFE4E1);
  static const Color textDark = Color(0xFF212121);
  static const Color textMuted = Color(0xFF757575);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFEF6C00);
  static const Color danger = Color(0xFFC62828);
}

/// Application theme. Deliberately calm and low-contrast: the app handles
/// sensitive disclosures, so the interface avoids alarming reds except for the
/// explicit emergency action.
class HerVoiceTheme {
  const HerVoiceTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: HerVoiceColors.pinkPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: HerVoiceColors.pinkPrimary,
      secondary: HerVoiceColors.pinkAccent,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: HerVoiceColors.backgroundTop,
      appBarTheme: const AppBarTheme(
        backgroundColor: HerVoiceColors.pinkPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HerVoiceColors.pinkMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HerVoiceColors.pinkMedium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(iconColor: HerVoiceColors.pinkPrimaryDark),
    );
  }

  /// Soft vertical gradient used behind the sign-in and home screens.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [HerVoiceColors.backgroundTop, HerVoiceColors.backgroundBottom],
  );
}
