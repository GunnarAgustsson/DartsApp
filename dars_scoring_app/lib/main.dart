import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dars_scoring_app/services/settings_service.dart';
import 'screens/home_screen.dart';
import 'theme/index.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove orientation lock to allow both portrait and landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Get initial theme settings from service
  final isDarkMode = await SettingsService.getDarkModeSetting();
  
  runApp(
    // Wrap with Provider to enable theme state management
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(initialDarkMode: isDarkMode),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Initialize theme settings on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      themeProvider.initializeTheme();
    });
    
    return MaterialApp(
      title: 'DARTS Scoring App',
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        // Apply text scaling factor for accessibility
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeProvider.textScaleFactor),
          ),
          child: child!,
        );
      },
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}