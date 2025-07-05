import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/killer_player.dart';

/// Service for managing Killer game state persistence
/// Handles saving/loading game state for pause/resume functionality
class KillerGameStateService {
  static const String _gameStateKey = 'killer_game_state';
  static const String _gameInProgressKey = 'killer_game_in_progress';

  /// Saves the current game state to persistent storage
  static Future<bool> saveGameState(KillerGameState gameState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(gameState.toJson());
      
      await prefs.setString(_gameStateKey, jsonString);
      await prefs.setBool(_gameInProgressKey, true);
      
      return true;
    } catch (e) {
      print('Error saving Killer game state: $e');
      return false;
    }
  }

  /// Loads the saved game state from persistent storage
  static Future<KillerGameState?> loadGameState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gameStateKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return KillerGameState.fromJson(jsonData);
    } catch (e) {
      print('Error loading Killer game state: $e');
      return null;
    }
  }

  /// Checks if there's a game in progress
  static Future<bool> hasGameInProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_gameInProgressKey) ?? false;
    } catch (e) {
      print('Error checking game progress: $e');
      return false;
    }
  }

  /// Clears the saved game state (called when game is completed or abandoned)
  static Future<bool> clearGameState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gameStateKey);
      await prefs.setBool(_gameInProgressKey, false);
      return true;
    } catch (e) {
      print('Error clearing Killer game state: $e');
      return false;
    }
  }

  /// Marks game as completed (keeps state for history but marks as not resumable)
  static Future<bool> markGameCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gameInProgressKey, false);
      return true;
    } catch (e) {
      print('Error marking game as completed: $e');
      return false;
    }
  }
}

/// Represents the complete state of a Killer game for persistence
class KillerGameState {
  /// List of all players with their current state
  final List<KillerPlayer> players;
  
  /// Index of the current player whose turn it is
  final int currentPlayerIndex;
  
  /// When the game was started
  final DateTime gameStartTime;
  
  /// Total number of darts thrown so far
  final int totalDartsThrown;
  
  /// Whether the game is completed
  final bool isCompleted;
  
  /// Winner's name (if game is completed)
  final String? winner;

  const KillerGameState({
    required this.players,
    required this.currentPlayerIndex,
    required this.gameStartTime,
    required this.totalDartsThrown,
    required this.isCompleted,
    this.winner,
  });

  /// Creates a copy with updated properties
  KillerGameState copyWith({
    List<KillerPlayer>? players,
    int? currentPlayerIndex,
    DateTime? gameStartTime,
    int? totalDartsThrown,
    bool? isCompleted,
    String? winner,
  }) {
    return KillerGameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      gameStartTime: gameStartTime ?? this.gameStartTime,
      totalDartsThrown: totalDartsThrown ?? this.totalDartsThrown,
      isCompleted: isCompleted ?? this.isCompleted,
      winner: winner ?? this.winner,
    );
  }

  /// Gets the current player
  KillerPlayer get currentPlayer => players[currentPlayerIndex];

  /// Gets all non-eliminated players
  List<KillerPlayer> get activePlayers => 
      players.where((player) => !player.isEliminated).toList();

  /// Checks if only one player remains (win condition)
  bool get hasWinner => activePlayers.length <= 1;

  /// Gets the winner (if game is won)
  KillerPlayer? get winnerPlayer => 
      hasWinner && activePlayers.isNotEmpty ? activePlayers.first : null;

  /// Converts this game state to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'players': players.map((player) => player.toJson()).toList(),
      'currentPlayerIndex': currentPlayerIndex,
      'gameStartTime': gameStartTime.toIso8601String(),
      'totalDartsThrown': totalDartsThrown,
      'isCompleted': isCompleted,
      'winner': winner,
    };
  }

  /// Creates a KillerGameState from JSON
  factory KillerGameState.fromJson(Map<String, dynamic> json) {
    return KillerGameState(
      players: (json['players'] as List)
          .map((playerJson) => KillerPlayer.fromJson(playerJson))
          .toList(),
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      gameStartTime: DateTime.parse(json['gameStartTime'] as String),
      totalDartsThrown: json['totalDartsThrown'] as int,
      isCompleted: json['isCompleted'] as bool,
      winner: json['winner'] as String?,
    );
  }

  @override
  String toString() {
    return 'KillerGameState(players: ${players.length}, currentPlayer: ${currentPlayer.name}, darts: $totalDartsThrown, completed: $isCompleted)';
  }
}
