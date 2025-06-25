import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/index.dart';
import '../services/settings_service.dart';
import '../models/app_enums.dart';
import '../data/possible_finishes.dart';

// Extension for CheckoutRule to provide user-friendly titles and descriptions
extension CheckoutRuleExtension on CheckoutRule {
  String get title {
    switch (this) {
      case CheckoutRule.doubleOut:
        return 'Standard Double‐Out';
      case CheckoutRule.extendedOut:
        return 'Extended Out';
      case CheckoutRule.exactOut:
        return 'Exact 0 Only';
      case CheckoutRule.openFinish:
        return 'Open Finish';
    }
  }

  String get description {
    switch (this) {
      case CheckoutRule.doubleOut:
        return 'Must finish on a double or bull.';
      case CheckoutRule.extendedOut:
        return 'Allow finish on double, triple, inner/outer bull.';
      case CheckoutRule.exactOut:
        return 'Any segment, but must land exactly on 0.';
      case CheckoutRule.openFinish:
        return 'First to 0 or below wins—no bust required.';
    }
  }
}

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late bool _soundEnabled;
  late bool _hapticFeedback;
  late AnimationSpeed _animationSpeed;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final soundEnabled = await SettingsService.getSoundEffectsSetting();
    final hapticFeedback = await SettingsService.getHapticFeedbackSetting();
    final animationSpeed = await SettingsService.getAnimationSpeed();
    
    setState(() {
      _soundEnabled = soundEnabled;
      _hapticFeedback = hapticFeedback;
      _animationSpeed = animationSpeed;
    });
  }
  
  Future<void> _toggleDarkMode(bool value) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setTheme(value);
  }

  Future<void> _updateAnimationSpeed(AnimationSpeed? value) async {
    if (value == null) return;
    setState(() => _animationSpeed = value);
    await SettingsService.saveAnimationSpeed(value);
  }
  
  /// Builds a section header with consistent styling
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Padding(
      padding: EdgeInsets.only(
        left: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
        right: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
        top: AppDimensions.paddingL,
        bottom: AppDimensions.paddingS,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Theme settings section
                _buildSectionHeader(context, 'Theme Settings'),
                
                SwitchListTile(
                  title: Text('Dark Mode', style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    'Enable dark theme for low-light environments',
                    style: theme.textTheme.bodySmall,
                  ),
                  secondary: Icon(
                    Provider.of<ThemeProvider>(context).isDarkMode ? 
                      Icons.dark_mode : Icons.light_mode,
                    color: theme.colorScheme.primary,
                  ),
                  value: Provider.of<ThemeProvider>(context).isDarkMode,
                  onChanged: _toggleDarkMode,
                ),                
                const Divider(indent: 16, endIndent: 16),
                
                // Sound & Haptics section
                _buildSectionHeader(context, 'Sound & Haptics'),
                SwitchListTile(
                  title: Text('Sound Effects', style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    'Play sound effects during the game',
                    style: theme.textTheme.bodySmall,
                  ),
                  secondary: Icon(
                    _soundEnabled ? Icons.volume_up : Icons.volume_off,
                    color: theme.colorScheme.primary,
                  ),
                  value: _soundEnabled,
                  onChanged: (value) async {
                    setState(() => _soundEnabled = value);
                    await SettingsService.saveSoundEffectsSetting(value);
                  },
                ),
                
                SwitchListTile(
                  title: Text('Haptic Feedback', style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    'Use vibration for button presses',
                    style: theme.textTheme.bodySmall,
                  ),
                  secondary: Icon(
                    _hapticFeedback ? Icons.vibration : Icons.do_not_disturb_alt,
                    color: theme.colorScheme.primary,
                  ),
                  value: _hapticFeedback,
                  onChanged: (value) async {
                    setState(() => _hapticFeedback = value);
                    await SettingsService.saveHapticFeedbackSetting(value);
                  },
                ),
                
                const Divider(indent: 16, endIndent: 16),
                
                // Animation Settings section
                _buildSectionHeader(context, 'Animation Settings'),
                
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
                    vertical: AppDimensions.paddingS,
                  ),
                  child: Text(
                    'Animation Speed',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                
                ...AnimationSpeed.values.map((speed) => Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.marginM,
                    vertical: AppDimensions.marginXS,
                  ),
                  child: RadioListTile<AnimationSpeed>(
                    title: Text(speed.title, style: theme.textTheme.titleSmall),
                    subtitle: Text(
                      speed.description,
                      style: theme.textTheme.bodySmall,
                    ),
                    value: speed,
                    groupValue: _animationSpeed,
                    activeColor: theme.colorScheme.primary,
                    onChanged: _updateAnimationSpeed,
                  ),
                )),

                const SizedBox(height: AppDimensions.marginL),
                _buildSectionHeader(context, 'Advanced'),
              ],
            ),
          ),
          
          // Danger zone section at bottom
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingL,
              horizontal: AppDimensions.paddingM,
            ),
            child: Card(
              color: theme.brightness == Brightness.dark 
                  ? AppColors.error.withOpacity(0.1) 
                  : AppColors.error.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: AppColors.error,
                      size: 32,
                    ),
                    const SizedBox(height: AppDimensions.marginS),
                    Text(
                      'Danger Zone',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.marginM),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Erase'),
                            content: const Text('Are you sure you want to erase all app data? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Erase', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All data erased'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_forever),
                          SizedBox(width: AppDimensions.marginS),
                          Text('Erase All Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}