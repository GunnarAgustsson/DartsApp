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
      body: Stack(
        children: [
          // Welcome message near the top, below the AppBar
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: const [
                  Text(
                    'Welcome to DARTS Scoring!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          // Menu centered on the screen
          Center(
            child: Column(
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
          ),
        ],
      ),
    );
  }
}