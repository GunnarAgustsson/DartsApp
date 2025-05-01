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
    final width = MediaQuery.of(context).size.width;
    final scale = width / 390; // 390 is a typical mobile width

    // Reusable variables for consistent sizing
    final double buttonWidth = 240 * scale;
    final double buttonHeight = 32 * scale;
    final double buttonFontSize = 20 * scale;
    final double buttonPaddingV = 8 * scale;
    final double titleFontSize = 24 * scale;
    final double iconCircleSize = 130 * scale;
    final double iconSize = 150 * scale;
    final double iconPadding = 10 * scale;
    final double sectionSpacing = 20 * scale;
    final double betweenButtonSpacing = 12 * scale;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DARTS Scoring App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: sectionSpacing),
            Text(
              'Welcome to DARTS Scoring!',
              style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: sectionSpacing),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Black circle background, just a bit larger than the icon
                  Container(
                    width: iconCircleSize,
                    height: iconCircleSize,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 17, 17, 17),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Dartboard icon, slightly smaller than the black circle
                  ClipOval(
                    child: Image.asset(
                      'assets/icons/dartboard.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: iconPadding),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(fontSize: buttonFontSize),
                      padding: EdgeInsets.symmetric(vertical: buttonPaddingV),
                    ),
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
                ),
                SizedBox(height: betweenButtonSpacing),
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(fontSize: buttonFontSize),
                      padding: EdgeInsets.symmetric(vertical: buttonPaddingV),
                    ),
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
                ),
                SizedBox(height: betweenButtonSpacing),
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(fontSize: buttonFontSize),
                      padding: EdgeInsets.symmetric(vertical: buttonPaddingV),
                    ),
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
                ),
                SizedBox(height: betweenButtonSpacing),
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(fontSize: buttonFontSize),
                      padding: EdgeInsets.symmetric(vertical: buttonPaddingV),
                    ),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}