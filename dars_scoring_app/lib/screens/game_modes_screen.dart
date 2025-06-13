import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'traditional_game_screen.dart';

class GameModeScreen extends StatefulWidget {
  const GameModeScreen({super.key});

  @override
  State<GameModeScreen> createState() => _GameModeScreenState();
}

class _GameModeScreenState extends State<GameModeScreen> {
  CheckoutRule _checkoutRule = CheckoutRule.values[0];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _checkoutRule = CheckoutRule.values[prefs.getInt('checkoutRule') ?? 0];
      });
    });
  }

  Future<List<String>> _getPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('players') ?? [];
  }

  Future<List<String>?> _showPlayerSelectionDialog(BuildContext context) async {
    final players = await _getPlayers();
    final selected = <String>[];
    return showDialog<List<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Select Players (max 8)'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: players.length,
              itemBuilder: (c, i) {
                final player = players[i];
                final isSelected = selected.contains(player);
                return ListTile(
                  leading: isSelected
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          child: Text('${selected.indexOf(player) + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        )
                      : const SizedBox(width: 24),
                  title: Text(player),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true && selected.length < 8) selected.add(player);
                        else selected.remove(player);
                      });
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected.isNotEmpty ? () => Navigator.pop(c, selected) : null,
              child: const Text('Start Game'),
            ),
          ],
        ),
      ),
    );
  }

  void _onGameModeSelected(BuildContext context, int startingScore) async {
    final selectedPlayers = await _showPlayerSelectionDialog(context);
    if (selectedPlayers != null && selectedPlayers.isNotEmpty) {
      // Persist selected rule
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('checkoutRule', _checkoutRule.index);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            startingScore: startingScore,
            players: selectedPlayers,
            initialRule: _checkoutRule,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 390;

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
            // Checkout rule selector
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Checkout Rule', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (var rule in CheckoutRule.values)
              RadioListTile<CheckoutRule>(
                title: Text(rule.toString().split('.').last),
                value: rule,
                groupValue: _checkoutRule,
                onChanged: (r) => setState(() => _checkoutRule = r!),
              ),
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