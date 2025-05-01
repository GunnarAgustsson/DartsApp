import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const DarsScoringApp());

class DarsScoringApp extends StatelessWidget {
  const DarsScoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DARS Scoring App',
      home: HomeScreen(),
    );
  }
}