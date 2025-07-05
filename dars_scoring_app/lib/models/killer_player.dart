import 'package:flutter/material.dart';

/// Represents a player in a Killer darts game
class KillerPlayer {
  /// Player's name
  final String name;
  
  /// Player's assigned territory (3 consecutive dartboard numbers)
  final List<int> territory;
  
  /// Player's current health (starts at 3, eliminated at 0)
  final int health;
  
  /// Whether this player has become a killer (hit their territory 3+ times)
  final bool isKiller;
  
  /// Number of times the player has hit their own territory
  final int hitCount;

  const KillerPlayer({
    required this.name,
    required this.territory,
    this.health = 3,
    this.isKiller = false,
    this.hitCount = 0,
  });

  /// Creates a copy of this player with updated properties
  KillerPlayer copyWith({
    String? name,
    List<int>? territory,
    int? health,
    bool? isKiller,
    int? hitCount,
  }) {
    return KillerPlayer(
      name: name ?? this.name,
      territory: territory ?? this.territory,
      health: health ?? this.health,
      isKiller: isKiller ?? this.isKiller,
      hitCount: hitCount ?? this.hitCount,
    );
  }

  /// Whether this player is eliminated (health <= 0)
  bool get isEliminated => health <= 0;

  /// Whether this player can attack others (is killer and not eliminated)
  bool get canAttack => isKiller && !isEliminated;

  /// Converts this player to a JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'territory': territory,
      'health': health,
      'isKiller': isKiller,
      'hitCount': hitCount,
    };
  }

  /// Creates a KillerPlayer from a JSON map
  factory KillerPlayer.fromJson(Map<String, dynamic> json) {
    return KillerPlayer(
      name: json['name'],
      territory: List<int>.from(json['territory']),
      health: json['health'],
      isKiller: json['isKiller'],
      hitCount: json['hitCount'],
    );
  }

  @override
  String toString() {
    return 'KillerPlayer(name: $name, territory: $territory, health: $health, isKiller: $isKiller, hitCount: $hitCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KillerPlayer &&
        other.name == name &&
        other.territory.length == territory.length &&
        other.territory.every((element) => territory.contains(element)) &&
        other.health == health &&
        other.isKiller == isKiller &&
        other.hitCount == hitCount;
  }

  @override
  int get hashCode {
    return Object.hash(name, territory, health, isKiller, hitCount);
  }
}

/// Represents visual territory information for dartboard rendering
class KillerPlayerTerritory {
  /// Player's name
  final String playerName;
  
  /// Territory areas to highlight (as strings for dartboard widget)
  final Set<String> areas;
  
  /// Player's color for highlighting
  final Color playerColor;
  
  /// Opacity for highlighting (based on health)
  final double highlightOpacity;
  
  /// Whether this player is eliminated
  final bool isEliminated;
  
  /// Whether this player is a killer
  final bool isKiller;
  
  /// Whether this is the current player's turn
  final bool isCurrentPlayer;
  
  /// Whether to show only border (for eliminated players)
  final bool borderOnly;
  
  /// Fill percentage based on health
  final double fillPercentage;
  
  /// Pulse intensity for current player
  final double pulseIntensity;
  
  /// Whether to show player name on territory
  final bool showPlayerName;

  const KillerPlayerTerritory({
    required this.playerName,
    required this.areas,
    required this.playerColor,
    this.highlightOpacity = 0.6,
    this.isEliminated = false,
    this.isKiller = false,
    this.isCurrentPlayer = false,
    this.borderOnly = false,
    this.fillPercentage = 1.0,
    this.pulseIntensity = 0.0,
    this.showPlayerName = false,
  });

  /// Creates a copy with updated properties
  KillerPlayerTerritory copyWith({
    String? playerName,
    Set<String>? areas,
    Color? playerColor,
    double? highlightOpacity,
    bool? isEliminated,
    bool? isKiller,
    bool? isCurrentPlayer,
    bool? borderOnly,
    double? fillPercentage,
    double? pulseIntensity,
    bool? showPlayerName,
  }) {
    return KillerPlayerTerritory(
      playerName: playerName ?? this.playerName,
      areas: areas ?? this.areas,
      playerColor: playerColor ?? this.playerColor,
      highlightOpacity: highlightOpacity ?? this.highlightOpacity,
      isEliminated: isEliminated ?? this.isEliminated,
      isKiller: isKiller ?? this.isKiller,
      isCurrentPlayer: isCurrentPlayer ?? this.isCurrentPlayer,
      borderOnly: borderOnly ?? this.borderOnly,
      fillPercentage: fillPercentage ?? this.fillPercentage,
      pulseIntensity: pulseIntensity ?? this.pulseIntensity,
      showPlayerName: showPlayerName ?? this.showPlayerName,
    );
  }
}
