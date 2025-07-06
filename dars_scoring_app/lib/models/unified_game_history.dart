import '../models/game_history.dart';
import '../models/cricket_game.dart';
import '../models/donkey_game.dart';
import '../models/killer_game_history.dart';

/// Game type enumeration
enum GameType {
  traditional,
  cricket,
  donkey,
  killer,
}

/// Unified game history model that can represent traditional, cricket, and donkey games
class UnifiedGameHistory {

  UnifiedGameHistory._({
    required this.id,
    required this.players,
    required this.createdAt,
    required this.modifiedAt,
    this.winner,
    this.completedAt,
    required this.gameMode,
    required this.gameType,
    this.traditionalGame,
    this.cricketGame,
    this.donkeyGame,
    this.killerGame,
  });

  /// Create from traditional game
  factory UnifiedGameHistory.fromTraditional(GameHistory traditional) {
    return UnifiedGameHistory._(
      id: traditional.id,
      players: traditional.players,
      createdAt: traditional.createdAt,
      modifiedAt: traditional.modifiedAt,
      winner: traditional.winner,
      completedAt: traditional.completedAt,
      gameMode: traditional.gameMode.toString(),
      gameType: GameType.traditional,
      traditionalGame: traditional,
    );
  }

  /// Create from cricket game
  factory UnifiedGameHistory.fromCricket(CricketGameHistory cricket) {
    return UnifiedGameHistory._(
      id: cricket.id,
      players: cricket.players,
      createdAt: cricket.createdAt,
      modifiedAt: cricket.modifiedAt,
      winner: cricket.winner,
      completedAt: cricket.completedAt,
      gameMode: cricket.gameMode,
      gameType: GameType.cricket,
      cricketGame: cricket,
    );
  }

  /// Create from donkey game
  factory UnifiedGameHistory.fromDonkey(DonkeyGameHistory donkey) {
    return UnifiedGameHistory._(
      id: '${donkey.startTime.millisecondsSinceEpoch}',
      players: donkey.originalPlayers,
      createdAt: donkey.startTime,
      modifiedAt: donkey.endTime ?? DateTime.now(),
      winner: donkey.winner,
      completedAt: donkey.endTime,
      gameMode: 'Donkey',
      gameType: GameType.donkey,
      donkeyGame: donkey,
    );
  }

  /// Create from killer game
  factory UnifiedGameHistory.fromKiller(KillerGameHistory killer) {
    return UnifiedGameHistory._(
      id: killer.id,
      players: killer.playerNames,
      createdAt: killer.gameStartTime,
      modifiedAt: killer.gameEndTime,
      winner: killer.winner,
      completedAt: killer.gameEndTime,
      gameMode: 'Killer',
      gameType: GameType.killer,
      killerGame: killer,
    );
  }

  /// Create from JSON - auto-detects game type
  factory UnifiedGameHistory.fromJson(Map<String, dynamic> json) {
    final gameMode = json['gameMode'];
    if (gameMode == 'Cricket') {
      return UnifiedGameHistory.fromCricket(CricketGameHistory.fromJson(json));
    } else if (gameMode == 'Donkey') {
      return UnifiedGameHistory.fromDonkey(DonkeyGameHistory.fromJson(json));
    } else if (gameMode == 'Killer') {
      return UnifiedGameHistory.fromKiller(KillerGameHistory.fromJson(json));
    } else {
      return UnifiedGameHistory.fromTraditional(GameHistory.fromJson(json));
    }
  }
  final String id;
  final List<String> players;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? winner;
  final DateTime? completedAt;
  final String gameMode; // 'Cricket', 'Donkey', or numeric like '301', '501'
  final GameType gameType;
  
  // For traditional games
  final GameHistory? traditionalGame;
  
  // For cricket games
  final CricketGameHistory? cricketGame;
  
  // For donkey games
  final DonkeyGameHistory? donkeyGame;
  
  // For killer games
  final KillerGameHistory? killerGame;

  /// Get throws count for display
  int get throwsCount {
    if (gameType == GameType.cricket) {
      return cricketGame?.throws.length ?? 0;
    } else if (gameType == GameType.donkey) {
      return donkeyGame?.turns.length ?? 0;
    } else if (gameType == GameType.killer) {
      return killerGame?.totalDartsThrown ?? 0;
    } else {
      return traditionalGame?.throws.length ?? 0;
    }
  }

  /// Get tag for history display
  String get gameTag {
    if (gameType == GameType.cricket) {
      return 'Cricket';
    } else if (gameType == GameType.donkey) {
      return 'Donkey';
    } else if (gameType == GameType.killer) {
      return 'Killer';
    } else {
      final mode = traditionalGame?.gameMode ?? 0;
      if (mode == 301) return 'Traditional 301';
      if (mode == 501) return 'Traditional 501';
      return 'Traditional $mode';
    }
  }
  /// Convert to JSON - delegates to underlying game type
  Map<String, dynamic> toJson() {
    if (gameType == GameType.cricket && cricketGame != null) {
      return cricketGame!.toJson();
    } else if (gameType == GameType.donkey && donkeyGame != null) {
      return donkeyGame!.toJson();
    } else if (gameType == GameType.killer && killerGame != null) {
      return killerGame!.toJson();
    } else if (traditionalGame != null) {
      return traditionalGame!.toJson();
    } else {
      throw StateError('No valid game data to serialize');
    }
  }
}
