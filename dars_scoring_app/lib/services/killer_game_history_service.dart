import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/killer_game_history.dart';

/// Service for managing Killer game history persistence
class KillerGameHistoryService {
  static const String _historyKey = 'killer_game_history';
  static const int _maxHistoryEntries = 100;

  /// Saves a completed Killer game to history
  static Future<bool> saveGameToHistory(KillerGameHistory gameHistory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentHistory = await loadGameHistory();
      
      // Add new game at the beginning (most recent first)
      currentHistory.insert(0, gameHistory);
      
      // Limit history size
      if (currentHistory.length > _maxHistoryEntries) {
        currentHistory.removeRange(_maxHistoryEntries, currentHistory.length);
      }
      
      // Convert to JSON and save
      final jsonList = currentHistory.map((game) => game.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      await prefs.setString(_historyKey, jsonString);
      return true;
    } catch (e) {
      print('Error saving Killer game history: $e');
      return false;
    }
  }

  /// Loads all Killer game history
  static Future<List<KillerGameHistory>> loadGameHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_historyKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final jsonList = json.decode(jsonString) as List;
      return jsonList
          .map((json) => KillerGameHistory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading Killer game history: $e');
      return [];
    }
  }

  /// Gets the most recent Killer games (limited count)
  static Future<List<KillerGameHistory>> getRecentGames({int limit = 10}) async {
    final allHistory = await loadGameHistory();
    return allHistory.take(limit).toList();
  }

  /// Clears all Killer game history
  static Future<bool> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      return true;
    } catch (e) {
      print('Error clearing Killer game history: $e');
      return false;
    }
  }

  /// Gets statistics from game history
  static Future<KillerGameStats> getGameStats() async {
    final history = await loadGameHistory();
    
    if (history.isEmpty) {
      return KillerGameStats.empty();
    }
    
    final totalGames = history.length;
    final totalDartsThrown = history.fold<int>(0, (sum, game) => sum + game.totalDartsThrown);
    final averageDartsPerGame = totalDartsThrown / totalGames;
    
    // Calculate average game duration
    final totalDuration = history.fold<Duration>(
      Duration.zero,
      (sum, game) => sum + game.gameDuration,
    );
    final averageDuration = Duration(
      milliseconds: (totalDuration.inMilliseconds / totalGames).round(),
    );
    
    // Find most common winner
    final winnerCounts = <String, int>{};
    for (final game in history) {
      winnerCounts[game.winner] = (winnerCounts[game.winner] ?? 0) + 1;
    }
    
    String? mostSuccessfulPlayer;
    int maxWins = 0;
    winnerCounts.forEach((player, wins) {
      if (wins > maxWins) {
        maxWins = wins;
        mostSuccessfulPlayer = player;
      }
    });
    
    return KillerGameStats(
      totalGames: totalGames,
      totalDartsThrown: totalDartsThrown,
      averageDartsPerGame: averageDartsPerGame,
      averageGameDuration: averageDuration,
      mostSuccessfulPlayer: mostSuccessfulPlayer,
      mostWins: maxWins,
    );
  }
}

/// Statistics for Killer games
class KillerGameStats {
  final int totalGames;
  final int totalDartsThrown;
  final double averageDartsPerGame;
  final Duration averageGameDuration;
  final String? mostSuccessfulPlayer;
  final int mostWins;

  const KillerGameStats({
    required this.totalGames,
    required this.totalDartsThrown,
    required this.averageDartsPerGame,
    required this.averageGameDuration,
    this.mostSuccessfulPlayer,
    required this.mostWins,
  });

  factory KillerGameStats.empty() {
    return const KillerGameStats(
      totalGames: 0,
      totalDartsThrown: 0,
      averageDartsPerGame: 0.0,
      averageGameDuration: Duration.zero,
      mostSuccessfulPlayer: null,
      mostWins: 0,
    );
  }
}
