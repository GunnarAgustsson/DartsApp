import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'traditional_game_screen.dart';
import '../models/game_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<GameHistory> games = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('games_history') ?? [];
    setState(() {
      games = raw.map((e) => GameHistory.fromJson(jsonDecode(e))).toList();
    });
  }

  void _showGameDetailsDialog(GameHistory game) {
    final wasCompleted = game.completedAt != null;
    final throws = game.throws;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Game Details'),
            if (wasCompleted && game.winner != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Winner: ${game.winner}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: throws.length,
              itemBuilder: (_, i) {
                final t = throws[i];
                return ListTile(
                  dense: true,
                  title: Text(t.player),
                  subtitle: Text(
                    'Hit: ${t.value} x${t.multiplier} | '
                    'Score after: ${t.resultingScore}'
                    '${t.wasBust ? '  (Bust)' : ''}',
                    style: t.wasBust
                        ? const TextStyle(color: Colors.red)
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          if (!wasCompleted)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      startingScore: game.gameMode,
                      players: game.players,
                      gameHistory: game,
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
      ),
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
              itemBuilder: (_, idx) {
                final game = games[idx];
                final date = game.createdAt.toLocal().toString().split('.')[0];
                final status = game.completedAt != null ? 'Completed' : 'In Progress';
                return ListTile(
                  title: Text('Game Mode: ${game.gameMode}'),
                  subtitle: Text('Date: $date\nPlayers: ${game.players.join(', ')}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          color: game.completedAt != null ? Colors.green : Colors.orange,
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
                            gamesRaw.removeAt(idx);
                            await prefs.setStringList('games_history', gamesRaw);
                            setState(() {
                              games.removeAt(idx);
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