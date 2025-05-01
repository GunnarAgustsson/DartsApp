import 'package:flutter/material.dart';
import 'players_screen.dart';
import 'game_modes_screen.dart';
import 'history_screen.dart';
import 'options_screen.dart';

class HomeScreen extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DARTS Scoring App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Welcome to DARTS Scoring!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Black circle background, just a bit larger than the icon
                  Container(
                    width: 250,
                    height: 250,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 17, 17, 17),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Dartboard icon, slightly smaller than the black circle
                  ClipOval(
                    child: Image.asset(
                      'assets/icons/dartboard.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameModeScreen(),
                      ),
                    );
                  },
                  child: const Text('New Game'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                  },
                  child: const Text('History'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayersScreen(),
                      ),
                    );
                  },
                  child: const Text('Players'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OptionsScreen(
                          isDarkMode: isDarkMode,
                          onThemeChanged: onThemeChanged,
                        ),
                      ),
                    );
                  },
                  child: const Text('Options'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}