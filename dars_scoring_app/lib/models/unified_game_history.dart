import '../models/game_history.dart';
import '../models/cricket_game.dart';

/// Unified game history model that can represent both traditional and cricket games
class UnifiedGameHistory {
  final String id;
  final List<String> players;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? winner;
  final DateTime? completedAt;
  final String gameMode; // 'Cricket' or numeric like '301', '501'
  final bool isCricket;
  
  // For traditional games
  final GameHistory? traditionalGame;
  
  // For cricket games
  final CricketGameHistory? cricketGame;

  UnifiedGameHistory._({
    required this.id,
    required this.players,
    required this.createdAt,
    required this.modifiedAt,
    this.winner,
    this.completedAt,
    required this.gameMode,
    required this.isCricket,
    this.traditionalGame,
    this.cricketGame,
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
      isCricket: false,
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
      isCricket: true,
      cricketGame: cricket,
    );
  }
  /// Create from JSON - auto-detects game type
  factory UnifiedGameHistory.fromJson(Map<String, dynamic> json) {
    final gameMode = json['gameMode'];
    if (gameMode == 'Cricket') {
      return UnifiedGameHistory.fromCricket(CricketGameHistory.fromJson(json));
    } else {
      return UnifiedGameHistory.fromTraditional(GameHistory.fromJson(json));
    }
  }

  /// Get throws count for display
  int get throwsCount {
    if (isCricket) {
      return cricketGame?.throws.length ?? 0;
    } else {
      return traditionalGame?.throws.length ?? 0;
    }
  }

  /// Get tag for history display
  String get gameTag {
    if (isCricket) {
      return 'Cricket';
    } else {
      final mode = traditionalGame?.gameMode ?? 0;
      if (mode == 301) return 'Traditional 301';
      if (mode == 501) return 'Traditional 501';
      return 'Traditional $mode';
    }
  }

  /// Convert to JSON - delegates to underlying game type
  Map<String, dynamic> toJson() {
    if (isCricket && cricketGame != null) {
      return cricketGame!.toJson();
    } else if (traditionalGame != null) {
      return traditionalGame!.toJson();
    } else {
      throw StateError('No valid game data to serialize');
    }
  }
}
