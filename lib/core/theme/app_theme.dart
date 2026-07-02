import 'package:flutter/material.dart';

class AppColors {
  static const primary = Colors.white;
  static const primaryGlow = Colors.white;
  
  static const surfaceDark = Color(0xFF1F1F22);
  static const surfaceLight = Color(0xFFE4E1E6);

  static const backgroundDark = Color(0xFF131316);
  static const backgroundLight = Color(0xFFF5F5F7);

  static const textDark = Color(0xFFE4E1E6);
  static const textLight = Color(0xFF1A1A1C);

  static const tertiary = Color(0xFFFFB783);
  static const error = Color(0xFFFFB4AB);
  
  static const surfaceLowestDark = Color(0xFF0E0E11);
  static const surfaceLowDark = Color(0xFF1B1B1E);
  static const surfaceHighDark = Color(0xFF2A2A2D);
  static const surfaceHighestDark = Color(0xFF353438);
}

class AppTheme {
  static const ColorScheme darkScheme = ColorScheme.dark(
    surface: Color(0xFF131316),
    primary: Colors.white,
    onPrimary: Colors.black,
    primaryContainer: Colors.white,
    onPrimaryContainer: Colors.black,
    secondary: Colors.white70,
    onSecondary: Colors.black,
    secondaryContainer: Color(0xFF2A2A2D),
    onSecondaryContainer: Colors.white,
    tertiary: Color(0xFFFFB783),
    onTertiary: Color(0xFF4F2500),
    tertiaryContainer: Color(0xFFD97721),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onSurface: Color(0xFFE4E1E6),
    onSurfaceVariant: Color(0xFFC7C4D7),
    outline: Color(0xFF908FA0),
    outlineVariant: Color(0xFF464554),
    surfaceContainerLowest: Color(0xFF0E0E11),
    surfaceContainerLow: Color(0xFF1B1B1E),
    surfaceContainer: Color(0xFF1F1F22),
    surfaceContainerHigh: Color(0xFF2A2A2D),
    surfaceContainerHighest: Color(0xFF353438),
    surfaceBright: Color(0xFF39393C),
    inverseSurface: Color(0xFFE4E1E6),
    onInverseSurface: Color(0xFF303033),
    inversePrimary: Colors.white38,
    surfaceTint: Colors.white,
  );

  static const ColorScheme lightScheme = ColorScheme.light(
    surface: Color(0xFFF5F5F7),
    primary: Colors.black,
    onPrimary: Colors.white,
    primaryContainer: Colors.black,
    onPrimaryContainer: Colors.white,
    secondary: Colors.black87,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE5E5E7),
    onSecondaryContainer: Colors.black,
    tertiary: Color(0xFFD97721),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFB783),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onSurface: Color(0xFF1A1A1C),
    onSurfaceVariant: Color(0xFF4A4A4C),
    outline: Color(0xFF7A7A7C),
    outlineVariant: Color(0xFFD2D2D4),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFEFEFEF),
    surfaceContainer: Color(0xFFE5E5E7),
    surfaceContainerHigh: Color(0xFFDDDDDF),
    surfaceContainerHighest: Color(0xFFD2D2D4),
    surfaceBright: Color(0xFFFBFBFC),
    inverseSurface: Color(0xFF1A1A1C),
    onInverseSurface: Color(0xFFF5F5F7),
    inversePrimary: Colors.black54,
    surfaceTint: Colors.black,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScheme.surface,
      colorScheme: darkScheme,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Color(0xFFE4E1E6), fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFFE4E1E6), fontFamily: 'Plus Jakarta Sans'),
        bodyMedium: TextStyle(color: Color(0xFFE4E1E6), fontFamily: 'Inter'),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScheme.surface,
      colorScheme: lightScheme,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Color(0xFF1A1A1C), fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFF1A1A1C), fontFamily: 'Plus Jakarta Sans'),
        bodyMedium: TextStyle(color: Color(0xFF1A1A1C), fontFamily: 'Inter'),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
