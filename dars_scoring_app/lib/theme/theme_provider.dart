import 'package:flutter/material.dart';
import 'package:dars_scoring_app/services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  
  ThemeProvider({bool initialDarkMode = false}) : _isDarkMode = initialDarkMode;
  bool _isDarkMode;
  double _textScaleFactor = 1.0;
  
  bool get isDarkMode => _isDarkMode;
  double get textScaleFactor => _textScaleFactor;
  
  /// Initialize theme from settings service
  Future<void> initializeTheme() async {
    // Get theme settings
    _isDarkMode = await SettingsService.getDarkModeSetting();
    _textScaleFactor = await SettingsService.getTextScaleFactor();
    notifyListeners();
  }
  
  /// Toggle between light and dark theme
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    
    // Save preference using the settings service
    await SettingsService.saveDarkModeSetting(_isDarkMode);
    notifyListeners();
  }
  
  /// Set a specific theme mode
  Future<void> setTheme(bool darkMode) async {
    if (_isDarkMode == darkMode) return;
    
    _isDarkMode = darkMode;
    await SettingsService.saveDarkModeSetting(_isDarkMode);
    notifyListeners();
  }
  
  /// Set text scale factor (for accessibility)
  Future<void> setTextScaleFactor(double factor) async {
    if (_textScaleFactor == factor) return;
    
    _textScaleFactor = factor;
    await SettingsService.saveTextScaleFactor(factor);
    notifyListeners();
  }
}
