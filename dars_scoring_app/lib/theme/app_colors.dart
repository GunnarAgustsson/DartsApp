import 'package:flutter/material.dart';

/// A centralized class for all colors used in the app
class AppColors {
  // Primary colors
  static const MaterialColor primaryGreen = MaterialColor(
    0xFF388E3C, // 500
    <int, Color>{
      50: Color(0xFFE8F5E9),
      100: Color(0xFFC8E6C9),
      200: Color(0xFFA5D6A7),
      300: Color(0xFF81C784),
      400: Color(0xFF66BB6A),
      500: Color(0xFF388E3C), // Primary color
      600: Color(0xFF2E7D32),
      700: Color(0xFF1B5E20),
      800: Color(0xFF155724),
      900: Color(0xFF0B371B),
    },
  );

  // Secondary colors
  static const MaterialColor secondaryRed = MaterialColor(
    0xFFD32F2F, // 500
    <int, Color>{
      50: Color(0xFFFFEBEE),
      100: Color(0xFFFFCDD2),
      200: Color(0xFFEF9A9A),
      300: Color(0xFFE57373),
      400: Color(0xFFEF5350),
      500: Color(0xFFD32F2F), // Secondary color
      600: Color(0xFFC62828),
      700: Color(0xFFB71C1C),
      800: Color(0xFF9A1515),
      900: Color(0xFF7F0000),
    },
  );

  // Light theme specific
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightScaffoldBackground = Color(0xFFF0F0F0);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);

  // Dark theme specific
  static const Color darkSurface = Color(0xFF303030);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkScaffoldBackground = Color(0xFF000000);
  static const Color darkCardBackground = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  // Game specific colors
  static const Color dartBoardRed = Color(0xFFBA0C2F);
  static const Color dartBoardGreen = Color(0xFF27AE60);
  static const Color dartBoardBlack = Color(0xFF121212);
  static const Color dartsFinishGold = Color(0xFFFFD700);
  
  // Status colors
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFDC3545);
  static const Color info = Color(0xFF17A2B8);
  
  // Specific component colors
  static const Color bustOverlayRed = Color(0xFFA02727);
  static const Color turnChangeBlue = Color(0xFF2196F3);
}
