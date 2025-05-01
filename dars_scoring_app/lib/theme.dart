import 'package:flutter/material.dart';

final ThemeData lightDartsTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.green[800]!,
    brightness: Brightness.light,
    primary: Colors.green[800],
    secondary: Colors.red[700],
    surface: Colors.grey[100],
  ),
  scaffoldBackgroundColor: Colors.grey[50],
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF388E3C),
    foregroundColor: Colors.white,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: Colors.black,
    displayColor: Colors.black,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green[800],
      foregroundColor: Colors.white,
    ),
  ),
);

final ThemeData darkDartsTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.green[900]!,
    brightness: Brightness.dark,
    primary: Colors.green[900],
    secondary: Colors.red[400],
    surface: Colors.grey[850]!,
  ),
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1B5E20),
    foregroundColor: Colors.white,
  ),
  textTheme: ThemeData.dark().textTheme.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green[900],
      foregroundColor: Colors.white,
    ),
  ),
);