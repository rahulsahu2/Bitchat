import 'package:flutter/material.dart';

class AppTheme {
  // WhatsApp-like signature green colors
  static const Color primaryGreen = Color(0xFF075E54);
  static const Color accentGreen = Color(0xFF128C7E);
  static const Color lightGreen = Color(0xFF25D366);
  static const Color chatBackgroundLight = Color(0xFFECE5DD);
  static const Color bubbleSentLight = Color(0xFFE2F9C3);
  static const Color bubbleReceivedLight = Colors.white;

  // Dark Mode colors
  static const Color darkBackground = Color(0xFF111B21);
  static const Color darkSurface = Color(0xFF202C33);
  static const Color bubbleSentDark = Color(0xFF005C4B);
  static const Color bubbleReceivedDark = Color(0xFF202C33);
  static const Color chatBackgroundDark = Color(0xFF0B141A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: accentGreen,
        secondary: lightGreen,
        background: Colors.white,
        surface: Color(0xFFF0F2F5),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: lightGreen,
        background: darkBackground,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}
