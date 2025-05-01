import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'traditional_game_screen.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import '../models/game_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> games = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> gamesRaw = prefs.getStringList('games_history') ?? [];
    setState(() {
      games = gamesRaw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  String _getGameMode(Map<String, dynamic> game) {
    return game['gameMode']?.toString() ?? 'Unknown';
  }

  String _shortenPlayers(String players, {int maxLength = 32}) {
    if (players.length <= maxLength) return players;
    return players.substring(0, maxLength - 3) + '...';
  }

  void _showGameDetailsDialog(Map<String, dynamic> game) {
    final throws = (game['throws'] as List)
        .map((t) => {
              'player': t['player'],
              'value': t['value'],
              'multiplier': t['multiplier'],
              'resultingScore': t['resultingScore'],
              'wasBust': t['wasBust'] ?? false,
            })
        .toList();
    final isCompleted = game['completedAt'] != null;
    final players = (game['players'] as List).cast<String>();
    final startingScore = _getGameMode(game) == '501'
        ? 501
        : _getGameMode(game) == '301'
            ? 301
            : 501;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Game Details'),
          content: SizedBox(
            width: double.maxFinite,
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: throws.length,
                itemBuilder: (context, index) {
                  final t = throws[index];
                  return ListTile(
                    dense: true,
                    title: Text('${t['player']}'),
                    subtitle: t['wasBust'] == true
                        ? Text(
                            'Hit: ${t['value']} x${t['multiplier']} | Score after: ${t['resultingScore']}  (Bust)',
                            style: const TextStyle(color: Colors.red),
                          )
                        : Text(
                            'Hit: ${t['value']} x${t['multiplier']} | Score after: ${t['resultingScore']}',
                          ),
                  );
                },
              ),
            ),
          ),
          actions: [
            if (!isCompleted)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GameScreen(
                        startingScore: startingScore,
                        players: players,
                        gameHistory: GameHistory.fromJson(game), // <-- Pass the loaded game
                      ),
                    ),
                  );
                },
                child: const Text('Continue Game'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game History')),
      body: games.isEmpty
          ? const Center(child: Text('No games played yet.'))
          : ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                final players = (game['players'] as List).join(', ');
                final date = DateTime.tryParse(game['createdAt'] ?? '') ?? DateTime.now();
                final isCompleted = game['completedAt'] != null;
                return ListTile(
                  title: Text('Game Mode: ${_getGameMode(game)}'),
                  subtitle: Text(
                    'Date: ${date.toLocal().toString().split('.')[0]}\n'
                    'Players: ${shortenName(players, maxLength: 32)}\n',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCompleted ? 'Completed' : 'In Progress',
                        style: TextStyle(
                          color: isCompleted ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Game'),
                              content: const Text('Are you sure you want to remove this game from history?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('No'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Yes'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final prefs = await SharedPreferences.getInstance();
                            final List<String> gamesRaw = prefs.getStringList('games_history') ?? [];
                            gamesRaw.removeAt(index);
                            await prefs.setStringList('games_history', gamesRaw);
                            setState(() {
                              games.removeAt(index);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => _showGameDetailsDialog(game),
                );
              },
            ),
    );
  }
}