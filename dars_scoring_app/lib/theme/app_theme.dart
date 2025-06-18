import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_dimensions.dart';

/// A central theme management class that generates light and dark themes
/// based on the app's design system.
class AppTheme {
  /// Get the light theme for the app
  static ThemeData getLightTheme() {
    return _getTheme(brightness: Brightness.light);
  }
  
  /// Get the dark theme for the app
  static ThemeData getDarkTheme() {
    return _getTheme(brightness: Brightness.dark);
  }
  
  /// Base theme generator that creates themed instances based on brightness
  static ThemeData _getTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark ? _getDarkColorScheme() : _getLightColorScheme();
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark 
          ? AppColors.darkScaffoldBackground 
          : AppColors.lightScaffoldBackground,
      
      // Text Theme
      textTheme: _getTextTheme(isDark: isDark),
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.primaryGreen.shade700 : AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.light,
        ),
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        elevation: AppDimensions.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        color: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        margin: const EdgeInsets.all(AppDimensions.marginS),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isDark ? AppColors.primaryGreen.shade700 : AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM,
          ),
          elevation: AppDimensions.elevationS,
          textStyle: AppTextStyles.buttonMedium(isDark: isDark),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.primaryGreen.shade300 : AppColors.primaryGreen,
          side: BorderSide(
            color: isDark ? AppColors.primaryGreen.shade300 : AppColors.primaryGreen,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM,
          ),
          textStyle: AppTextStyles.buttonMedium(isDark: isDark),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.primaryGreen.shade300 : AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          textStyle: AppTextStyles.buttonSmall(isDark: isDark),
        ),
      ),
      
      // Icon Theme
      iconTheme: IconThemeData(
        color: isDark ? AppColors.primaryGreen.shade300 : AppColors.primaryGreen,
        size: AppDimensions.iconM,
      ),
      
      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: AppDimensions.elevationM,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryGreen.shade300 : AppColors.primaryGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(
            color: isDark ? AppColors.error : AppColors.error,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingM,
        ),
      ),
    );
  }
  
  // Generate a light color scheme
  static ColorScheme _getLightColorScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryGreen.shade100,
      onPrimaryContainer: AppColors.primaryGreen.shade900,
      secondary: AppColors.secondaryRed,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryRed.shade100,
      onSecondaryContainer: AppColors.secondaryRed.shade900,
      tertiary: Colors.amber,
      onTertiary: Colors.black,
      tertiaryContainer: Colors.amber.shade100,
      onTertiaryContainer: Colors.amber.shade900,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: Colors.grey.shade100,
      onSurfaceVariant: Colors.grey.shade700,
      outline: Colors.grey.shade400,
      shadow: Colors.black.withOpacity(0.1),
      inverseSurface: Colors.grey.shade900,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.primaryGreen.shade200,
    );
  }
  
  // Generate a dark color scheme
  static ColorScheme _getDarkColorScheme() {
    return ColorScheme(
      brightness: Brightness.dark,
      // Use the same main colors as the light theme for consistency
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      secondary: AppColors.secondaryRed,
      onSecondary: Colors.white,
      tertiary: Colors.amber,
      onTertiary: Colors.black,
      error: AppColors.error,
      onError: Colors.white,

      // Dark theme specific container colors
      primaryContainer: AppColors.primaryGreen.shade700,
      onPrimaryContainer: AppColors.primaryGreen.shade100,
      secondaryContainer: AppColors.secondaryRed.shade700,
      onSecondaryContainer: AppColors.secondaryRed.shade100,
      tertiaryContainer: Colors.amber.shade700,
      onTertiaryContainer: Colors.amber.shade100,
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),

      // Dark theme surface and background colors
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: Colors.grey.shade800,
      onSurfaceVariant: Colors.grey.shade300,
      outline: Colors.grey.shade600,
      shadow: Colors.black.withOpacity(0.3),
      inverseSurface: Colors.grey.shade200,
      onInverseSurface: Colors.grey.shade900,
      inversePrimary: AppColors.primaryGreen.shade200,
    );
  }
  
  // Generate appropriate text theme
  static TextTheme _getTextTheme({required bool isDark}) {
    return TextTheme(
      // Display
      displayLarge: AppTextStyles.headlineLarge(isDark: isDark),
      displayMedium: AppTextStyles.headlineMedium(isDark: isDark),
      displaySmall: AppTextStyles.headlineSmall(isDark: isDark),
      
      // Headline
      headlineLarge: AppTextStyles.headlineLarge(isDark: isDark),
      headlineMedium: AppTextStyles.headlineMedium(isDark: isDark),
      headlineSmall: AppTextStyles.headlineSmall(isDark: isDark),
      
      // Title
      titleLarge: AppTextStyles.titleLarge(isDark: isDark),
      titleMedium: AppTextStyles.titleMedium(isDark: isDark),
      titleSmall: AppTextStyles.titleSmall(isDark: isDark),
      
      // Body
      bodyLarge: AppTextStyles.bodyLarge(isDark: isDark),
      bodyMedium: AppTextStyles.bodyMedium(isDark: isDark),
      bodySmall: AppTextStyles.bodySmall(isDark: isDark),
      
      // Label
      labelLarge: AppTextStyles.buttonLarge(isDark: isDark),
      labelMedium: AppTextStyles.buttonMedium(isDark: isDark),
      labelSmall: AppTextStyles.buttonSmall(isDark: isDark),
    );
  }
}
