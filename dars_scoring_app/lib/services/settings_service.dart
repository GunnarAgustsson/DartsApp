import 'package:shared_preferences/shared_preferences.dart';

/// A service class to manage app settings and preferences
class SettingsService {
  // Keys for SharedPreferences
  static const String darkModeKey = 'darkMode';
  static const String hapticFeedbackKey = 'hapticFeedback';
  static const String soundEffectsKey = 'soundEffects';
  static const String animationsEnabledKey = 'animationsEnabled';
  static const String textScaleFactorKey = 'textScaleFactor';
  
  /// Save dark mode preference
  static Future<void> saveDarkModeSetting(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(darkModeKey, isDarkMode);
  }
  
  /// Get dark mode preference
  static Future<bool> getDarkModeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(darkModeKey) ?? false; // Default to light mode
  }
  
  /// Save haptic feedback preference
  static Future<void> saveHapticFeedbackSetting(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hapticFeedbackKey, isEnabled);
  }
  
  /// Get haptic feedback preference
  static Future<bool> getHapticFeedbackSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hapticFeedbackKey) ?? true; // Default to enabled
  }
  
  /// Save sound effects preference
  static Future<void> saveSoundEffectsSetting(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(soundEffectsKey, isEnabled);
  }
  
  /// Get sound effects preference
  static Future<bool> getSoundEffectsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(soundEffectsKey) ?? true; // Default to enabled
  }
  
  /// Save animations preference
  static Future<void> saveAnimationsEnabledSetting(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(animationsEnabledKey, isEnabled);
  }
  
  /// Get animations preference
  static Future<bool> getAnimationsEnabledSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(animationsEnabledKey) ?? true; // Default to enabled
  }
  
  /// Save text scale factor preference (for accessibility)
  static Future<void> saveTextScaleFactor(double factor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(textScaleFactorKey, factor);
  }
  
  /// Get text scale factor preference
  static Future<double> getTextScaleFactor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(textScaleFactorKey) ?? 1.0; // Default to normal scale
  }
}
