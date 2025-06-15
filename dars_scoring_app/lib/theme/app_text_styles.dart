import 'package:flutter/material.dart';

/// A centralized class for text styles used throughout the app
class AppTextStyles {
  static const String fontFamily = 'Roboto';
  
  // Main title styles
  static TextStyle headlineLarge({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: isDark ? Colors.white : Colors.black,
  );
  
  static TextStyle headlineMedium({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: isDark ? Colors.white : Colors.black,
  );
  
  static TextStyle headlineSmall({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: isDark ? Colors.white : Colors.black,
  );

  // Title & subtitle styles
  static TextStyle titleLarge({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white : Colors.black,
  );
  
  static TextStyle titleMedium({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white : Colors.black,
  );
  
  static TextStyle titleSmall({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white : Colors.black,
  );

  // Body text styles
  static TextStyle bodyLarge({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: isDark ? Colors.white : Colors.black,
  );
  
  static TextStyle bodyMedium({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: isDark ? Colors.white : Colors.black,
  );
  
  static TextStyle bodySmall({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: isDark ? Colors.white : Colors.black,
  );

  // Button text styles
  static TextStyle buttonLarge({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: isDark ? Colors.white : Colors.white,
  );
  
  static TextStyle buttonMedium({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: isDark ? Colors.white : Colors.white,
  );
  
  static TextStyle buttonSmall({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: isDark ? Colors.white : Colors.white,
  );

  // Game specific styles
  static TextStyle gameScore({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: isDark ? Colors.white : Colors.black,
  );
  
  static TextStyle dartThrow({required bool isDark}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white : Colors.black87,
  );
  
  // Overlay text styles
  static TextStyle bustOverlay() => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 64,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 4,
  );

  static TextStyle turnChangeOverlay() => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 1,
  );
}
