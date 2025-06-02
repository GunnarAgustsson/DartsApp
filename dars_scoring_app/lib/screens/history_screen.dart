import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Add this dependency for date formatting
import 'dart:convert';
import 'package:collection/collection.dart'; // For grouping
import 'traditional_game_screen.dart';
import '../models/game_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<GameHistory> games = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('games_history') ?? [];
    
    setState(() {
      games = raw
        .map((e) => GameHistory.fromJson(jsonDecode(e)))
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
      isLoading = false;
    });
  }

  // Group games by date (today, yesterday, this week, earlier)
  Map<String, List<GameHistory>> _getGroupedGames() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    
    return groupBy(games, (GameHistory game) {
      final gameDate = DateTime(
        game.createdAt.year, 
        game.createdAt.month, 
        game.createdAt.day
      );
      
      if (gameDate.isAtSameMomentAs(today)) return 'Today';
      if (gameDate.isAtSameMomentAs(yesterday)) return 'Yesterday';
      if (gameDate.isAfter(thisWeekStart)) return 'This Week';
      return 'Earlier';
    });
  }

  Future<void> _deleteGame(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> gamesRaw = prefs.getStringList('games_history') ?? [];
    
    // Find the game ID to delete
    final gameToDelete = games[idx];
    final rawIdx = gamesRaw.indexWhere((raw) {
      final game = jsonDecode(raw);
      return game['id'] == gameToDelete.id;
    });
    
    if (rawIdx >= 0) {
      gamesRaw.removeAt(rawIdx);
      await prefs.setStringList('games_history', gamesRaw);
      setState(() {
        games.removeAt(idx);
      });
    }
  }

  void _showGameDetailsDialog(GameHistory game) {
    final wasCompleted = game.completedAt != null;
    final throws = game.throws;
    
    // Group throws by player for a better view
    final throwsByPlayer = groupBy(throws, (DartThrow t) => t.player);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: wasCompleted 
                ? Colors.green.shade100 
                : Colors.orange.shade100,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${game.gameMode} Game',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(
                      wasCompleted ? 'Completed' : 'In Progress',
                      style: TextStyle(
                        color: wasCompleted ? Colors.green.shade900 : Colors.orange.shade900,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: wasCompleted 
                        ? Colors.green.shade50 
                        : Colors.orange.shade50,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Players: ${game.players.join(", ")}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              if (wasCompleted && game.winner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Winner: ${game.winner}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: throwsByPlayer.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No throws recorded in this game.'),
                ))
            : DefaultTabController(
                length: throwsByPlayer.length,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: throwsByPlayer.keys.map((player) => 
                        Tab(text: player)
                      ).toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: throwsByPlayer.entries.map((entry) {
                          final player = entry.key;
                          final playerThrows = entry.value;
                          
                          return ListView.separated(
                            itemCount: playerThrows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final t = playerThrows[i];
                              final dartLabel = _getDartLabel(t);
                              return ListTile(
                                dense: true,
                                title: Text(
                                  dartLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: t.wasBust 
                                        ? Colors.red 
                                        : t.resultingScore == 0 
                                            ? Colors.green 
                                            : null,
                                  ),
                                ),
                                subtitle: Text(
                                  'Score after: ${t.resultingScore}',
                                ),
                                trailing: t.wasBust 
                                    ? const Chip(
                                        label: Text('BUST', 
                                          style: TextStyle(
                                            color: Colors.white, 
                                            fontSize: 12,
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                      )
                                    : t.resultingScore == 0
                                        ? const Chip(
                                            label: Text('FINISH', 
                                              style: TextStyle(
                                                color: Colors.white, 
                                                fontSize: 12,
                                              ),
                                            ),
                                            backgroundColor: Colors.green,
                                          )
                                        : null,
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
        ),
        actions: [
          if (!wasCompleted)
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Continue Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
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
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  String _getDartLabel(DartThrow t) {
    if (t.value == 0) return 'Miss';
    if (t.value == 50) return 'Double Bull (50)';
    if (t.value == 25) return 'Single Bull (25)';
    if (t.multiplier == 3) return 'Triple ${t.value} (${t.value * 3})';
    if (t.multiplier == 2) return 'Double ${t.value} (${t.value * 2})';
    return 'Single ${t.value}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (games.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game History')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No games played yet',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Your game history will appear here',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final groupedGames = _getGroupedGames();
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGames,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: groupedGames.entries.map((entry) {
          final title = entry.key;
          final sectionGames = entry.value;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              ...sectionGames.asMap().entries.map((gameEntry) {
                final gameIdx = games.indexOf(gameEntry.value); // Global index
                final game = gameEntry.value;
                final wasCompleted = game.completedAt != null;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  child: InkWell(
                    onTap: () => _showGameDetailsDialog(game),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: wasCompleted 
                                ? Colors.green.shade100 
                                : Colors.orange.shade100,
                            child: Icon(
                              wasCompleted ? Icons.done : Icons.hourglass_empty,
                              color: wasCompleted 
                                  ? Colors.green.shade700 
                                  : Colors.orange.shade700,
                            ),
                          ),
                          title: Text(
                            '${game.gameMode} Game',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateFormat.format(game.createdAt.toLocal())),
                              const SizedBox(height: 4),
                              Text(
                                'Players: ${game.players.join(", ")}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: wasCompleted && game.winner != null 
                              ? Tooltip(
                                  message: 'Winner: ${game.winner}',
                                  child: Icon(
                                    Icons.emoji_events,
                                    color: Colors.amber.shade700,
                                  ),
                                )
                              : null,
                          isThreeLine: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(
                                  wasCompleted ? 'Completed' : 'In Progress',
                                  style: TextStyle(
                                    color: wasCompleted 
                                        ? Colors.green.shade900 
                                        : Colors.orange.shade900,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: wasCompleted 
                                    ? Colors.green.shade50 
                                    : Colors.orange.shade50,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!wasCompleted)
                                    TextButton.icon(
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Continue'),
                                      onPressed: () {
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
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Game'),
                                          content: const Text(
                                            'Are you sure you want to remove this game from history?'
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _deleteGame(gameIdx);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}