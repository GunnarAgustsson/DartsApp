import 'package:dars_scoring_app/models/killer_player.dart';

/// Represents a completed Killer game for history tracking
class KillerGameHistory {
  /// Unique identifier for this game instance
  final String id;
  
  /// When the game was started
  final DateTime gameStartTime;
  
  /// When the game was completed
  final DateTime gameEndTime;
  
  /// List of all players who participated
  final List<String> playerNames;
  
  /// The winner of the game
  final String winner;
  
  /// Total number of darts thrown in the game
  final int totalDartsThrown;
  
  /// Duration of the game
  Duration get gameDuration => gameEndTime.difference(gameStartTime);
  
  /// Map of player names to their final territories
  final Map<String, List<int>> playerTerritories;
  
  /// Map of player names to their final health values
  final Map<String, int> finalPlayerHealth;

  const KillerGameHistory({
    required this.id,
    required this.gameStartTime,
    required this.gameEndTime,
    required this.playerNames,
    required this.winner,
    required this.totalDartsThrown,
    required this.playerTerritories,
    required this.finalPlayerHealth,
  });

  /// Creates a KillerGameHistory from completed game data
  factory KillerGameHistory.fromGameData({
    required DateTime gameStartTime,
    required List<KillerPlayer> players,
    required String winner,
    required int totalDartsThrown,
  }) {
    final id = 'killer_${DateTime.now().millisecondsSinceEpoch}';
    final playerNames = players.map((p) => p.name).toList();
    final playerTerritories = <String, List<int>>{};
    final finalPlayerHealth = <String, int>{};
    
    for (final player in players) {
      playerTerritories[player.name] = List.from(player.territory);
      finalPlayerHealth[player.name] = player.health;
    }
    
    return KillerGameHistory(
      id: id,
      gameStartTime: gameStartTime,
      gameEndTime: DateTime.now(),
      playerNames: playerNames,
      winner: winner,
      totalDartsThrown: totalDartsThrown,
      playerTerritories: playerTerritories,
      finalPlayerHealth: finalPlayerHealth,
    );
  }

  /// Converts this history entry to a JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameMode': 'Killer', // For unified game history compatibility
      'gameStartTime': gameStartTime.toIso8601String(),
      'gameEndTime': gameEndTime.toIso8601String(),
      'playerNames': playerNames,
      'winner': winner,
      'totalDartsThrown': totalDartsThrown,
      'playerTerritories': playerTerritories,
      'finalPlayerHealth': finalPlayerHealth,
    };
  }

  /// Creates a KillerGameHistory from a JSON map
  factory KillerGameHistory.fromJson(Map<String, dynamic> json) {
    return KillerGameHistory(
      id: json['id'] as String,
      gameStartTime: DateTime.parse(json['gameStartTime'] as String),
      gameEndTime: DateTime.parse(json['gameEndTime'] as String),
      playerNames: List<String>.from(json['playerNames'] as List),
      winner: json['winner'] as String,
      totalDartsThrown: json['totalDartsThrown'] as int,
      playerTerritories: Map<String, List<int>>.from(
        (json['playerTerritories'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, List<int>.from(value as List)),
        ),
      ),
      finalPlayerHealth: Map<String, int>.from(
        json['finalPlayerHealth'] as Map<String, dynamic>
      ),
    );
  }

  @override
  String toString() {
    return 'KillerGameHistory(id: $id, players: $playerNames, winner: $winner, duration: ${gameDuration.inMinutes}min)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KillerGameHistory &&
        other.id == id &&
        other.gameStartTime == gameStartTime &&
        other.gameEndTime == gameEndTime &&
        other.playerNames.length == playerNames.length &&
        other.playerNames.every((name) => playerNames.contains(name)) &&
        other.winner == winner &&
        other.totalDartsThrown == totalDartsThrown;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      gameStartTime,
      gameEndTime,
      playerNames,
      winner,
      totalDartsThrown,
    );
  }
}
