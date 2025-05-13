import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'traditional_game_screen.dart';

class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});

  Future<List<String>> _getPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('players') ?? [];
  }

  Future<List<String>?> _showPlayerSelectionDialog(BuildContext context) async {
    final players = await _getPlayers();
    final selected = <String>[]; // use List to keep insertion order

    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Select Players (max 8)'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isSelected = selected.contains(player);
                  final order = isSelected ? selected.indexOf(player) + 1 : null;

                  return ListTile(
                    leading: isSelected
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            child: Text(
                              '$order',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : const SizedBox(width: 24), // reserve space so things don’t shift
                    title: Text(player),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true && selected.length < 8) {
                            selected.add(player);
                          } else {
                            selected.remove(player);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selected.isNotEmpty
                    ? () => Navigator.of(context).pop(selected.toList())
                    : null,
                child: const Text('Start Game'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onGameModeSelected(BuildContext context, int startingScore) async {
    final selectedPlayers = await _showPlayerSelectionDialog(context);
    if (selectedPlayers != null && selectedPlayers.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            startingScore: startingScore,
            players: selectedPlayers,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 390; // 390 is a typical mobile width

    // Reusable variables for consistent sizing
    final double buttonWidth = 240 * scale;
    final double buttonHeight = 56 * scale;
    final double buttonFontSize = 22 * scale;
    final double buttonPaddingV = 16 * scale;
    final double sectionSpacing = 32 * scale;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Game Mode'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  textStyle: TextStyle(fontSize: buttonFontSize),
                  padding: EdgeInsets.symmetric(vertical: buttonPaddingV),
                ),
                onPressed: () => _onGameModeSelected(context, 501),
                child: const Text('501'),
              ),
            ),
            SizedBox(height: sectionSpacing),
            SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  textStyle: TextStyle(fontSize: buttonFontSize),
                  padding: EdgeInsets.symmetric(vertical: buttonPaddingV),
                ),
                onPressed: () => _onGameModeSelected(context, 301),
                child: const Text('301'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}