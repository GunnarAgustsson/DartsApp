import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:collection/collection.dart';

import '../models/unified_game_history.dart';
import '../models/app_enums.dart';
import '../screens/traditional_game_screen.dart';
import '../screens/cricket_game_screen.dart';
import '../screens/donkey_game_screen.dart';
import '../screens/killer_game_screen.dart';

/// A reusable widget that displays game history with optional player filtering
/// Can be used in both the main history screen and player info screen
class GameHistoryView extends StatefulWidget {
  
  const GameHistoryView({
    super.key,
    this.playerFilter,
    this.showRefreshButton = true,
    this.allowDelete = true,
    this.maxGames,
    this.emptyStateWidget,
  });
  /// Optional player name to filter games by. If null, shows all games.
  final String? playerFilter;
  
  /// Whether to show the refresh action button
  final bool showRefreshButton;
  
  /// Whether to show delete buttons for games
  final bool allowDelete;
  
  /// Maximum number of games to display. If null, shows all games.
  final int? maxGames;
  
  /// Custom empty state widget
  final Widget? emptyStateWidget;

  @override
  State<GameHistoryView> createState() => _GameHistoryViewState();
}

class _GameHistoryViewState extends State<GameHistoryView> {
  List<UnifiedGameHistory> games = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  /// Reload games when the widget is updated with a different player filter
  @override
  void didUpdateWidget(GameHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerFilter != widget.playerFilter) {
      _loadGames();
    }
  }

  Future<void> _loadGames() async {
    setState(() => isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load all game types
    final traditionalRaw = prefs.getStringList('games_history') ?? [];
    final cricketRaw = prefs.getStringList('cricket_games') ?? [];
    final donkeyRaw = prefs.getStringList('donkey_games') ?? [];
    final killerRaw = prefs.getStringList('killer_game_history') ?? [];
    
    List<UnifiedGameHistory> allGames = [];
    
    // Parse traditional games
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
    
    // Parse donkey games
    for (String rawGame in donkeyRaw) {
      try {
        final game = UnifiedGameHistory.fromJson(jsonDecode(rawGame));
        allGames.add(game);
      } catch (e) {
        debugPrint('Error parsing donkey game: $e');
      }
    }
    
    // Parse killer games
    for (String rawGame in killerRaw) {
      try {
        final game = UnifiedGameHistory.fromJson(jsonDecode(rawGame));
        allGames.add(game);
      } catch (e) {
        debugPrint('Error parsing killer game: $e');
      }
    }

    // Filter by player if specified
    if (widget.playerFilter != null) {
      allGames = allGames
          .where((game) => game.players.contains(widget.playerFilter!))
          .toList();
    }
    
    // Sort by date (most recent first) and apply max limit
    allGames.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (widget.maxGames != null && allGames.length > widget.maxGames!) {
      allGames = allGames.take(widget.maxGames!).toList();
    }
    
    setState(() {
      games = allGames;
      isLoading = false;
    });
  }

  /// Group games by date for better organization
  Map<String, List<UnifiedGameHistory>> _getGroupedGames() {
    if (widget.maxGames != null && widget.maxGames! <= 10) {
      // For small lists (like in player info), don't group by date
      return {'Recent Games': games};
    }
    
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

  Future<void> _deleteGame(int globalIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final gameToDelete = games[globalIndex];
    
    if (gameToDelete.gameType == GameType.cricket) {
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
    } else if (gameToDelete.gameType == GameType.donkey) {
      // Delete from donkey games
      final List<String> donkeyGamesRaw = prefs.getStringList('donkey_games') ?? [];
      final rawIdx = donkeyGamesRaw.indexWhere((raw) {
        final game = jsonDecode(raw);
        return game['id'] == gameToDelete.id;
      });
      
      if (rawIdx >= 0) {
        donkeyGamesRaw.removeAt(rawIdx);
        await prefs.setStringList('donkey_games', donkeyGamesRaw);
      }
    } else if (gameToDelete.gameType == GameType.killer) {
      // Delete from killer games
      final List<String> killerGamesRaw = prefs.getStringList('killer_game_history') ?? [];
      final rawIdx = killerGamesRaw.indexWhere((raw) {
        final game = jsonDecode(raw);
        return game['id'] == gameToDelete.id;
      });
      
      if (rawIdx >= 0) {
        killerGamesRaw.removeAt(rawIdx);
        await prefs.setStringList('killer_game_history', killerGamesRaw);
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
      games.removeAt(globalIndex);
    });
  }

  void _showGameDetailsDialog(UnifiedGameHistory game) {
    if (game.gameType == GameType.cricket) {
      _showCricketGameDetails(game.cricketGame!);
    } else if (game.gameType == GameType.donkey) {
      _showDonkeyGameDetails(game.donkeyGame!);
    } else if (game.gameType == GameType.killer) {
      _showKillerGameDetails(game.killerGame!);
    } else {
      _showTraditionalGameDetails(game.traditionalGame!);
    }
  }

  void _showTraditionalGameDetails(dynamic traditionalGame) {
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
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: throwsByPlayer.entries.map((entry) {
                      final player = entry.key;
                      final playerThrows = entry.value;
                      
                      return ExpansionTile(
                        title: Text(player, style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: playerThrows.map((dartThrow) {
                          return ListTile(
                            dense: true,
                            title: dartThrow.wasBust == true
                                ? Text(
                                    'Hit: ${dartThrow.value} x${dartThrow.multiplier} | Score after: ${dartThrow.resultingScore}  (Bust)',
                                    style: const TextStyle(color: Colors.red),
                                  )
                                : Text(
                                    'Hit: ${dartThrow.value} x${dartThrow.multiplier} | Score after: ${dartThrow.resultingScore}',
                                  ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
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
    
    // Group throws by player
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
          height: 200,
          child: SingleChildScrollView(
            child: Column(
              children: throwsByPlayer.entries.map((entry) {
                final player = entry.key;
                final playerThrows = entry.value;
                
                return ExpansionTile(
                  title: Text(player, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: playerThrows.map((dartThrow) {
                    return ListTile(
                      dense: true,
                      title: Text('Hit: ${dartThrow.value} x${dartThrow.multiplier}'),
                    );
                  }).toList(),
                );
              }).toList(),
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

  void _showDonkeyGameDetails(dynamic donkeyGame) {
    final wasCompleted = donkeyGame.completedAt != null;
    
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
                    'Donkey Game',
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
                'Players: ${donkeyGame.originalPlayers.join(", ")}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              if (wasCompleted && donkeyGame.eliminatedPlayers != null && donkeyGame.eliminatedPlayers!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Winner: ${donkeyGame.originalPlayers.firstWhere((p) => !donkeyGame.eliminatedPlayers!.contains(p), orElse: () => 'Unknown')}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          height: 100,
          child: Center(
            child: Text('Donkey game details not fully implemented yet'),
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
                _resumeGame(UnifiedGameHistory.fromDonkey(donkeyGame));
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

  void _showKillerGameDetails(dynamic killerGame) {
    final wasCompleted = killerGame.isGameComplete;
    
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
                    'Killer Game',
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
                'Players: ${killerGame.players.map((p) => p.name).join(", ")}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              if (wasCompleted && killerGame.winner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Winner: ${killerGame.winner}',
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
        content: const SizedBox(
          width: double.maxFinite,
          height: 100,
          child: Center(
            child: Text('Killer game details not fully implemented yet'),
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
                _resumeGame(UnifiedGameHistory.fromKiller(killerGame));
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

  void _resumeGame(UnifiedGameHistory game) {
    if (game.gameType == GameType.cricket) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CricketGameScreen(
            players: game.players,
            gameHistory: game.cricketGame,
            variant: CricketVariant.standard, // Default for resumed games
          ),
        ),
      );
    } else if (game.gameType == GameType.donkey) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DonkeyGameScreen(
            players: game.donkeyGame!.originalPlayers,
            gameHistory: game.donkeyGame,
            randomOrder: false, // Default for resumed games
            variant: game.donkeyGame!.variant,
          ),
        ),
      );
    } else if (game.gameType == GameType.killer) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KillerGameScreen(
            playerNames: game.players,
            randomOrder: false, // Default for resumed games
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

  Widget _buildEmptyState() {
    if (widget.emptyStateWidget != null) {
      return widget.emptyStateWidget!;
    }
    
    String emptyMessage = widget.playerFilter != null 
        ? 'No games found for ${widget.playerFilter}'
        : 'No games played yet';
    String emptySubMessage = widget.playerFilter != null
        ? 'This player hasn\'t played any games yet'
        : 'Your game history will appear here';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            emptySubMessage,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (games.isEmpty) {
      return _buildEmptyState();
    }

    final groupedGames = _getGroupedGames();
    final dateFormat = DateFormat('MMM d, h:mm a');

    return RefreshIndicator(
      onRefresh: _loadGames,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (widget.showRefreshButton)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.playerFilter != null 
                        ? '${widget.playerFilter}\'s Games (${games.length})'
                        : 'Game History (${games.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadGames,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
          ...groupedGames.entries.map((entry) {
            final title = entry.key;
            final sectionGames = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (groupedGames.length > 1) // Only show section headers if we have multiple sections
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
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
                                        label: const Text('Continue'),
                                        onPressed: () {
                                          _resumeGame(game);
                                        },
                                      ),
                                    if (widget.allowDelete)
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
          }),
        ],
      ),
    );
  }
}
