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
  DateTime createdAt, modifiedAt;
  final List<DartThrow> throws;
  String? winner;
  DateTime? completedAt;
  final int gameMode;

  int currentPlayer;
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