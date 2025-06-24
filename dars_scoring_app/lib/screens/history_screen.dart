import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Add this dependency for date formatting
import 'dart:convert';
import 'package:collection/collection.dart'; // For grouping
import 'traditional_game_screen.dart';
import 'cricket_game_screen.dart';
import '../models/unified_game_history.dart';
import '../models/app_enums.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<UnifiedGameHistory> games = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadGames();
  }  Future<void> _loadGames() async {
    setState(() => isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load traditional games
    final traditionalRaw = prefs.getStringList('games_history') ?? [];
    debugPrint('Loading traditional games, raw count: ${traditionalRaw.length}');
    
    // Load cricket games
    final cricketRaw = prefs.getStringList('cricket_games') ?? [];
    debugPrint('Loading cricket games, raw count: ${cricketRaw.length}');
    
    List<UnifiedGameHistory> allGames = [];    // Parse traditional games
    for (String rawGame in traditionalRaw) {
      try {
        final game = UnifiedGameHistory.fromJson(jsonDecode(rawGame));
        allGames.add(game);
      } catch (e) {
        debugPrint('Error parsing traditional game: $e');
      }
    }
    
    // Parse cricket games
    for (String rawGame in cricketRaw) {
      try {
        final game = UnifiedGameHistory.fromJson(jsonDecode(rawGame));
        allGames.add(game);
      } catch (e) {
        debugPrint('Error parsing cricket game: $e');
      }
    }
    
    setState(() {
      games = allGames..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
      isLoading = false;
      
      debugPrint('Parsed ${games.length} total games successfully (${traditionalRaw.length} traditional, ${cricketRaw.length} cricket)');
    });
  }

  // Group games by date (today, yesterday, this week, earlier)
  Map<String, List<UnifiedGameHistory>> _getGroupedGames() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    
    return groupBy(games, (UnifiedGameHistory game) {
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
    final gameToDelete = games[idx];
    
    if (gameToDelete.isCricket) {
      // Delete from cricket games
      final List<String> cricketGamesRaw = prefs.getStringList('cricket_games') ?? [];
      final rawIdx = cricketGamesRaw.indexWhere((raw) {
        final game = jsonDecode(raw);
        return game['id'] == gameToDelete.id;
      });
      
      if (rawIdx >= 0) {
        cricketGamesRaw.removeAt(rawIdx);
        await prefs.setStringList('cricket_games', cricketGamesRaw);
      }
    } else {
      // Delete from traditional games
      final List<String> traditionalGamesRaw = prefs.getStringList('games_history') ?? [];
      final rawIdx = traditionalGamesRaw.indexWhere((raw) {
        final game = jsonDecode(raw);
        return game['id'] == gameToDelete.id;
      });
      
      if (rawIdx >= 0) {
        traditionalGamesRaw.removeAt(rawIdx);
        await prefs.setStringList('games_history', traditionalGamesRaw);
      }
    }
    
    setState(() {
      games.removeAt(idx);
    });
  }void _showGameDetailsDialog(UnifiedGameHistory game) {
    if (!game.isCricket) {
      _showTraditionalGameDetails(game.traditionalGame!);
    } else {
      _showCricketGameDetails(game.cricketGame!);
    }
  }  void _showTraditionalGameDetails(dynamic traditionalGame) {
    final wasCompleted = traditionalGame.completedAt != null;
    final throws = traditionalGame.throws as List;
    
    // Group throws by player for a better view
    final throwsByPlayer = groupBy(throws, (dartThrow) => dartThrow.player as String);
    
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
                    '${traditionalGame.gameMode} Game',
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
                'Players: ${traditionalGame.players.join(", ")}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              if (wasCompleted && traditionalGame.winner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Winner: ${traditionalGame.winner}',
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
                        Tab(text: player.toString())
                      ).toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: throwsByPlayer.entries.map((entry) {
                          final playerThrows = entry.value;
                          
                          return ListView.separated(
                            itemCount: playerThrows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final t = playerThrows[i];
                              final dartLabel = _getTraditionalDartLabel(t);
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
              ),              onPressed: () {
                Navigator.of(context).pop();
                _resumeGame(UnifiedGameHistory.fromTraditional(traditionalGame));
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
  void _showCricketGameDetails(dynamic cricketGame) {
    final wasCompleted = cricketGame.completedAt != null;
    final throws = cricketGame.throws as List;
    
    // Group throws by player for a better view
    final throwsByPlayer = groupBy(throws, (dartThrow) => dartThrow.player as String);
    
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
                  const Text(
                    'Cricket Game',
                    style: TextStyle(
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
                'Players: ${cricketGame.players.join(", ")}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              if (wasCompleted && cricketGame.winner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Winner: ${cricketGame.winner}',
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
                        Tab(text: player.toString())
                      ).toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: throwsByPlayer.entries.map((entry) {
                          final playerThrows = entry.value;
                          
                          return ListView.separated(
                            itemCount: playerThrows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final t = playerThrows[i];
                              final dartLabel = _getCricketDartLabel(t);
                              return ListTile(
                                dense: true,
                                title: Text(
                                  dartLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),                                subtitle: Text(
                                  'Value: ${t.value}, Hits: ${t.hits}',
                                ),
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
              ),              onPressed: () {
                Navigator.of(context).pop();
                _resumeGame(UnifiedGameHistory.fromCricket(cricketGame));
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
  
  String _getCricketDartLabel(dynamic dartThrow) {
    final value = dartThrow.value;
    final multiplier = dartThrow.multiplier;
    
    if (value == 0) return 'Miss';
    if (value == 25) return multiplier == 2 ? 'DB' : 'Bull';
    if (multiplier == 2) return 'D$value';
    if (multiplier == 3) return 'T$value';
    return '$value';
  }

  String _getTraditionalDartLabel(dynamic dartThrow) {
    final value = dartThrow.value;
    final multiplier = dartThrow.multiplier;
    
    if (value == 0) return 'Miss';
    if (value == 50) return 'DB'; // Double Bull
    if (value == 25) return '25'; // Single Bull
    if (multiplier == 2) return 'D$value';
    if (multiplier == 3) return 'T$value';
    return '$value';
  }

  void _resumeGame(UnifiedGameHistory game) {
    if (game.isCricket) {
      Navigator.of(context).push(        MaterialPageRoute(
          builder: (_) => CricketGameScreen(
            players: game.players,
            gameHistory: game.cricketGame,
            variant: CricketVariant.standard, // Default for resumed games
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            startingScore: game.traditionalGame!.gameMode,
            players: game.players,
            gameHistory: game.traditionalGame,
          ),
        ),
      );
    }
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
                          ),                          title: Text(
                            game.gameTag,
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
                                      label: const Text('Continue'),                                      onPressed: () {
                                        _resumeGame(game);
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