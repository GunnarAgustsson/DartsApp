import 'app_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Donkey Game Models - HORSE-style darts game
// ─────────────────────────────────────────────────────────────────────────────

/// Player state in a Donkey game
class DonkeyPlayerState { // Player is out when they spell "DONKEY"

  const DonkeyPlayerState({
    required this.name,
    this.letters = '',
    this.isEliminated = false,
  });

  /// Create from JSON
  factory DonkeyPlayerState.fromJson(Map<String, dynamic> json) {
    return DonkeyPlayerState(
      name: json['name'] as String,
      letters: json['letters'] as String? ?? '',
      isEliminated: json['isEliminated'] as bool? ?? false,
    );
  }
  final String name;
  final String letters; // Letters earned (e.g., "D", "DO", "DON", etc.)
  final bool isEliminated;

  /// Create a copy with updated values
  DonkeyPlayerState copyWith({
    String? name,
    String? letters,
    bool? isEliminated,
  }) {
    return DonkeyPlayerState(
      name: name ?? this.name,
      letters: letters ?? this.letters,
      isEliminated: isEliminated ?? this.isEliminated,
    );
  }

  /// Add a letter to this player's collection
  DonkeyPlayerState addLetter() {
    const donkeyLetters = 'DONKEY';
    final currentLetterCount = letters.length;
    
    if (currentLetterCount >= donkeyLetters.length) {
      return this; // Already has all letters
    }

    final newLetters = letters + donkeyLetters[currentLetterCount];
    final newIsEliminated = newLetters.length >= donkeyLetters.length;

    return copyWith(
      letters: newLetters,
      isEliminated: newIsEliminated,
    );
  }

  /// Get the next letter this player would receive
  String get nextLetter {
    const donkeyLetters = 'DONKEY';
    final currentLetterCount = letters.length;
    
    if (currentLetterCount >= donkeyLetters.length) {
      return ''; // Already has all letters
    }

    return donkeyLetters[currentLetterCount];
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'letters': letters,
      'isEliminated': isEliminated,
    };
  }

  @override
  String toString() {
    return 'DonkeyPlayerState(name: $name, letters: $letters, isEliminated: $isEliminated)';
  }
}

/// Single turn result in Donkey game
class DonkeyTurn {

  const DonkeyTurn({
    required this.playerName,
    required this.score,
    required this.dartLabels,
    required this.beatTarget,
    required this.receivedLetter,
  });

  /// Create from JSON
  factory DonkeyTurn.fromJson(Map<String, dynamic> json) {
    return DonkeyTurn(
      playerName: json['playerName'] as String,
      score: json['score'] as int,
      dartLabels: List<String>.from(json['dartLabels'] as List),
      beatTarget: json['beatTarget'] as bool,
      receivedLetter: json['receivedLetter'] as bool,
    );
  }
  final String playerName;
  final int score;
  final List<String> dartLabels; // e.g., ["20", "T19", "D5"]
  final bool beatTarget;
  final bool receivedLetter;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'score': score,
      'dartLabels': dartLabels,
      'beatTarget': beatTarget,
      'receivedLetter': receivedLetter,
    };
  }

  @override
  String toString() {
    return 'DonkeyTurn(player: $playerName, score: $score, darts: $dartLabels, beat: $beatTarget, letter: $receivedLetter)';
  }
}

/// Complete Donkey game state
class DonkeyGameHistory {

  const DonkeyGameHistory({
    required this.originalPlayers,
    required this.playerStates,
    required this.turns,
    required this.variant,
    this.lastFinisher,
    this.currentTarget = 0,
    this.targetSetBy = '',
    required this.startTime,
    this.endTime,
  });

  /// Create from JSON
  factory DonkeyGameHistory.fromJson(Map<String, dynamic> json) {
    return DonkeyGameHistory(
      originalPlayers: List<String>.from(json['originalPlayers'] as List),
      playerStates: (json['playerStates'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, DonkeyPlayerState.fromJson(value as Map<String, dynamic>)),
      ),
      turns: (json['turns'] as List).map((turn) => DonkeyTurn.fromJson(turn as Map<String, dynamic>)).toList(),
      variant: DonkeyVariant.values.firstWhere((v) => v.name == json['variant']),
      lastFinisher: json['lastFinisher'] as String?,
      currentTarget: json['currentTarget'] as int? ?? 0,
      targetSetBy: json['targetSetBy'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
    );
  }
  final List<String> originalPlayers;
  final Map<String, DonkeyPlayerState> playerStates;
  final List<DonkeyTurn> turns;
  final DonkeyVariant variant;
  final String? lastFinisher;
  final int currentTarget; // Score to beat
  final String targetSetBy; // Player who set the current target
  final DateTime startTime;
  final DateTime? endTime;

  /// Create a copy with updated values
  DonkeyGameHistory copyWith({
    List<String>? originalPlayers,
    Map<String, DonkeyPlayerState>? playerStates,
    List<DonkeyTurn>? turns,
    DonkeyVariant? variant,
    String? lastFinisher,
    int? currentTarget,
    String? targetSetBy,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return DonkeyGameHistory(
      originalPlayers: originalPlayers ?? this.originalPlayers,
      playerStates: playerStates ?? this.playerStates,
      turns: turns ?? this.turns,
      variant: variant ?? this.variant,
      lastFinisher: lastFinisher ?? this.lastFinisher,
      currentTarget: currentTarget ?? this.currentTarget,
      targetSetBy: targetSetBy ?? this.targetSetBy,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// Get active players (not eliminated)
  List<String> get activePlayers {
    return originalPlayers
        .where((player) => !playerStates[player]!.isEliminated)
        .toList();
  }

  /// Check if game is finished (only one player left)
  bool get isGameFinished {
    return activePlayers.length <= 1;
  }

  /// Get the winner (last remaining player)
  String? get winner {
    final active = activePlayers;
    return active.length == 1 ? active.first : null;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': '${startTime.millisecondsSinceEpoch}',
      'gameMode': 'Donkey',
      'gameType': 'donkey',
      'originalPlayers': originalPlayers,
      'playerStates': playerStates.map((key, value) => MapEntry(key, value.toJson())),
      'turns': turns.map((turn) => turn.toJson()).toList(),
      'variant': variant.name,
      'lastFinisher': lastFinisher,
      'currentTarget': currentTarget,
      'targetSetBy': targetSetBy,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      // UnifiedGameHistory fields
      'players': originalPlayers,
      'createdAt': startTime.toIso8601String(),
      'modifiedAt': (endTime ?? DateTime.now()).toIso8601String(),
      'winner': winner,
      'completedAt': endTime?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'DonkeyGameHistory(players: $originalPlayers, variant: $variant, target: $currentTarget, finished: $isGameFinished)';
  }
}
