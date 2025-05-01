class DartThrow {
  final String player;
  final int value;
  final int multiplier;
  final int resultingScore;
  final DateTime timestamp;
  final bool wasBust;

  DartThrow({
    required this.player,
    required this.value,
    required this.multiplier,
    required this.resultingScore,
    required this.timestamp,
    this.wasBust = false,
  });

  Map<String, dynamic> toJson() => {
        'player': player,
        'value': value,
        'multiplier': multiplier,
        'resultingScore': resultingScore,
        'timestamp': timestamp.toIso8601String(),
        'wasBust': wasBust,
      };

  static DartThrow fromJson(Map<String, dynamic> json) => DartThrow(
        player: json['player'],
        value: json['value'],
        multiplier: json['multiplier'],
        resultingScore: json['resultingScore'],
        timestamp: DateTime.parse(json['timestamp']),
        wasBust: json['wasBust'] ?? false,
      );
}

class GameHistory {
  final String id;
  final List<String> players;
  final DateTime createdAt;
  DateTime modifiedAt;
  DateTime? completedAt;
  final List<DartThrow> throws;
  final int gameMode; // <-- Add this

  GameHistory({
    required this.id,
    required this.players,
    required this.createdAt,
    required this.modifiedAt,
    required this.throws,
    required this.gameMode, // <-- Add this
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'players': players,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'throws': throws.map((e) => e.toJson()).toList(),
        'gameMode': gameMode, // <-- Add this
      };

  static GameHistory fromJson(Map<String, dynamic> json) => GameHistory(
        id: json['id'],
        players: List<String>.from(json['players']),
        createdAt: DateTime.parse(json['createdAt']),
        modifiedAt: DateTime.parse(json['modifiedAt']),
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
        throws: (json['throws'] as List).map((e) => DartThrow.fromJson(e)).toList(),
        gameMode: json['gameMode'] ?? 501, // fallback for old games
      );
}