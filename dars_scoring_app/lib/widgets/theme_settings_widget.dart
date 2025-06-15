import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dars_scoring_app/theme/theme_provider.dart';
import 'package:dars_scoring_app/theme/app_dimensions.dart';
import 'package:dars_scoring_app/services/settings_service.dart';

/// A widget that shows theme and accessibility settings
class ThemeSettingsWidget extends StatefulWidget {
  const ThemeSettingsWidget({super.key});

  @override
  State<ThemeSettingsWidget> createState() => _ThemeSettingsWidgetState();
}

class _ThemeSettingsWidgetState extends State<ThemeSettingsWidget> {
  bool _isDarkMode = false;
  bool _hapticFeedback = true;
  bool _soundEffects = true;
  double _textScaleFactor = 1.0;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final isDarkMode = await SettingsService.getDarkModeSetting();
    final hapticFeedback = await SettingsService.getHapticFeedbackSetting();
    final soundEffects = await SettingsService.getSoundEffectsSetting();
    final textScaleFactor = await SettingsService.getTextScaleFactor();
    
    if (mounted) {
      setState(() {
        _isDarkMode = isDarkMode;
        _hapticFeedback = hapticFeedback;
        _soundEffects = soundEffects;
        _textScaleFactor = textScaleFactor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Text(
            'Theme & Accessibility',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.marginM,
            vertical: AppDimensions.marginS,
          ),
          child: Column(
            children: [
              // Dark mode toggle
              SwitchListTile(
                title: Text(
                  'Dark Mode',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Enable dark theme',
                  style: theme.textTheme.bodyMedium,
                ),
                secondary: Icon(
                  Icons.dark_mode,
                  color: theme.colorScheme.primary,
                ),
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() => _isDarkMode = value);
                  themeProvider.setTheme(value);
                },
              ),
              
              const Divider(),
              
              // Haptic feedback toggle
              SwitchListTile(
                title: Text(
                  'Haptic Feedback',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Vibration on button presses',
                  style: theme.textTheme.bodyMedium,
                ),
                secondary: Icon(
                  Icons.vibration,
                  color: theme.colorScheme.primary,
                ),
                value: _hapticFeedback,
                onChanged: (value) async {
                  setState(() => _hapticFeedback = value);
                  await SettingsService.saveHapticFeedbackSetting(value);
                },
              ),
              
              const Divider(),
              
              // Sound effects toggle
              SwitchListTile(
                title: Text(
                  'Sound Effects',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Play sounds during the game',
                  style: theme.textTheme.bodyMedium,
                ),
                secondary: Icon(
                  Icons.volume_up,
                  color: theme.colorScheme.primary,
                ),
                value: _soundEffects,
                onChanged: (value) async {
                  setState(() => _soundEffects = value);
                  await SettingsService.saveSoundEffectsSetting(value);
                },
              ),
              
              const Divider(),
              
              // Text size slider
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.text_fields,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        'Text Size',
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        'Adjust the size of text throughout the app',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.marginS),
                    Row(
                      children: [
                        const Text('A', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Slider(
                            value: _textScaleFactor,
                            min: 0.8,
                            max: 1.4,
                            divisions: 6,
                            label: _getTextSizeLabel(_textScaleFactor),
                            onChanged: (value) {
                              setState(() => _textScaleFactor = value);
                            },
                            onChangeEnd: (value) async {
                              await SettingsService.saveTextScaleFactor(value);
                              themeProvider.setTextScaleFactor(value);
                            },
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _getTextSizeLabel(double value) {
    if (value <= 0.8) return 'Small';
    if (value <= 0.9) return 'Medium-Small';
    if (value <= 1.0) return 'Medium';
    if (value <= 1.1) return 'Medium-Large';
    if (value <= 1.2) return 'Large';
    if (value <= 1.3) return 'X-Large';
    return 'XX-Large';
  }
}
