class CricketThrow {
  final String player;
  final int value; // 20, 19, 18, 17, 16, 15, or 25 (bull)
  final int multiplier; // 1, 2, or 3
  final DateTime timestamp;
  final int hits; // How many hits this throw gives (multiplier)
  final bool wasBust;

  CricketThrow({
    required this.player,
    required this.value,
    required this.multiplier,
    required this.timestamp,
    this.wasBust = false,
  }) : hits = multiplier;

  Map<String, dynamic> toJson() => {
        'player': player,
        'value': value,
        'multiplier': multiplier,
        'timestamp': timestamp.toIso8601String(),
        'hits': hits,
        'wasBust': wasBust,
      };

  static CricketThrow fromJson(Map<String, dynamic> json) => CricketThrow(
        player: json['player'],
        value: json['value'],
        multiplier: json['multiplier'],
        timestamp: DateTime.parse(json['timestamp']),
        wasBust: json['wasBust'] ?? false,
      );
}

class CricketPlayerState {
  final String name;
  int score = 0;
  
  // Track hits on each number (20, 19, 18, 17, 16, 15, bull)
  final Map<int, int> hits = {
    20: 0,
    19: 0,
    18: 0,
    17: 0,
    16: 0,
    15: 0,
    25: 0, // Bull
  };

  CricketPlayerState(this.name);

  // Check if a number is closed (3 or more hits)
  bool isNumberClosed(int number) => hits[number]! >= 3;

  // Check if all numbers are closed
  bool get allNumbersClosed {
    return hits.values.every((hitCount) => hitCount >= 3);
  }

  // Get remaining hits needed to close a number
  int hitsNeededToClose(int number) {
    return (3 - hits[number]!).clamp(0, 3);
  }
  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'hits': hits.map((key, value) => MapEntry(key.toString(), value)),
      };
  static CricketPlayerState fromJson(Map<String, dynamic> json) {
    final state = CricketPlayerState(json['name']);
    state.score = json['score'];
    
    // Convert string keys back to integers
    final hitsMap = json['hits'] as Map<String, dynamic>;
    for (final entry in hitsMap.entries) {
      final key = int.parse(entry.key);
      state.hits[key] = entry.value;
    }
    
    return state;
  }
}

class CricketGameHistory {
  final String id;
  final List<String> players;
  DateTime createdAt, modifiedAt;
  final List<CricketThrow> throws;
  String? winner;
  DateTime? completedAt;
  final String gameMode = 'Cricket'; // Always Cricket

  int currentPlayer;
  int dartsThrown;
  final Map<String, CricketPlayerState> playerStates;

  CricketGameHistory({
    required this.id,
    required this.players,
    required this.createdAt,
    required this.modifiedAt,
    required this.throws,
    this.winner,
    this.completedAt,
    this.currentPlayer = 0,
    this.dartsThrown = 0,
    Map<String, CricketPlayerState>? playerStates,
  }) : playerStates = playerStates ?? {
          for (String player in players) player: CricketPlayerState(player)
        };

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
        'playerStates': {
          for (String player in players)
            player: playerStates[player]!.toJson()
        },
      };

  factory CricketGameHistory.fromJson(Map<String, dynamic> j) {
    final players = List<String>.from(j['players']);
    final playerStates = <String, CricketPlayerState>{};
    
    if (j['playerStates'] != null) {
      final statesJson = j['playerStates'] as Map<String, dynamic>;
      for (String player in players) {
        if (statesJson.containsKey(player)) {
          playerStates[player] = CricketPlayerState.fromJson(statesJson[player]);
        } else {
          playerStates[player] = CricketPlayerState(player);
        }
      }
    } else {
      // Fallback for older saves
      for (String player in players) {
        playerStates[player] = CricketPlayerState(player);
      }
    }

    return CricketGameHistory(
      id: j['id'],
      players: players,
      createdAt: DateTime.parse(j['createdAt']),
      modifiedAt: DateTime.parse(j['modifiedAt']),
      throws: (j['throws'] as List).map((e) => CricketThrow.fromJson(e)).toList(),
      winner: j['winner'],
      completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt']),
      currentPlayer: j['currentPlayer'] ?? 0,
      dartsThrown: j['dartsThrown'] ?? 0,
      playerStates: playerStates,
    );
  }
}
