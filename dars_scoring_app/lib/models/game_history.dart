/// Represents a single dart throw in a game, capturing player, hit value,
/// multiplier, resulting score, timestamp, and whether it was a bust.
class DartThrow {
  /// Name of the player who threw.
  final String player;

  /// The raw value hit (0 for miss, 1–20, 25, or 50).
  final int value;

  /// Multiplier applied (1, 2, or 3).
  final int multiplier;

  /// Score remaining after this throw.
  final int resultingScore;

  /// Time when the throw occurred.
  final DateTime timestamp;

  /// Whether this throw resulted in a bust.
  final bool wasBust;

  DartThrow({
    required this.player,
    required this.value,
    required this.multiplier,
    required this.resultingScore,
    required this.timestamp,
    this.wasBust = false,
  });

  /// Serializes this throw into a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'player': player,
        'value': value,
        'multiplier': multiplier,
        'resultingScore': resultingScore,
        'timestamp': timestamp.toIso8601String(),
        'wasBust': wasBust,
      };

  /// Deserializes a [DartThrow] from a JSON map.
  static DartThrow fromJson(Map<String, dynamic> json) => DartThrow(
        player: json['player'],
        value: json['value'],
        multiplier: json['multiplier'],
        resultingScore: json['resultingScore'],
        timestamp: DateTime.parse(json['timestamp']),
        wasBust: json['wasBust'] ?? false,
      );
}  // Close DartThrow class

/// Records the full history of a darts game, including throw list, turn state,
/// finish information, and persistence metadata.
class GameHistory {
  /// Unique identifier for this game instance.
  final String id;

  /// Ordered list of player names participating.
  final List<String> players;

  /// When the game was created.
  DateTime createdAt;

  /// Last modification timestamp.
  DateTime modifiedAt;

  /// List of all [DartThrow] records in this game.
  final List<DartThrow> throws;

  /// Winner player name, if the game is complete.
  String? winner;

  /// Timestamp when the game finished, or null if ongoing.
  DateTime? completedAt;

  /// Game mode (starting score, e.g., 301, 501).
  final int gameMode;

  /// Index of current player whose turn it is.
  int currentPlayer;

  /// Number of darts thrown by current player this turn.
  int dartsThrown;

  GameHistory({
    required this.id,
    required this.players,
    required this.createdAt,
    required this.modifiedAt,
    required this.throws,
    this.winner,
    this.completedAt,
    required this.gameMode,
    this.currentPlayer = 0,
    this.dartsThrown = 0,
  });

  /// Converts the game history to a JSON-compatible map for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'players': players,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'throws': throws.map((t) => t.toJson()).toList(),
        'winner': winner,
        'completedAt': completedAt?.toIso8601String(),
        'gameMode': gameMode,
        'currentPlayer': currentPlayer,
        'dartsThrown': dartsThrown,
      };

  /// Creates a [GameHistory] instance from a JSON map.
  factory GameHistory.fromJson(Map<String, dynamic> j) => GameHistory(
        id: j['id'],
        players: List<String>.from(j['players']),
        createdAt: DateTime.parse(j['createdAt']),
        modifiedAt: DateTime.parse(j['modifiedAt']),
        throws: (j['throws'] as List).map((e) => DartThrow.fromJson(e)).toList(),
        winner: j['winner'],
        completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt']),
        gameMode: j['gameMode'],
        currentPlayer: j['currentPlayer'] ?? 0,
        dartsThrown: j['dartsThrown'] ?? 0,
      );
}