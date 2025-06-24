import 'app_enums.dart';
import '../data/possible_finishes.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Data classes for game setup and configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Details for setting up a traditional game (301, 501, 1001)
class PlayerSelectionDetails {
  final List<String> players;
  final CheckoutRule checkoutRule;
  final int startingScore;
  final bool randomOrder;

  const PlayerSelectionDetails({
    required this.players,
    required this.checkoutRule,
    required this.startingScore,
    required this.randomOrder,
  });

  /// Create a copy with updated values
  PlayerSelectionDetails copyWith({
    List<String>? players,
    CheckoutRule? checkoutRule,
    int? startingScore,
    bool? randomOrder,
  }) {
    return PlayerSelectionDetails(
      players: players ?? this.players,
      checkoutRule: checkoutRule ?? this.checkoutRule,
      startingScore: startingScore ?? this.startingScore,
      randomOrder: randomOrder ?? this.randomOrder,
    );
  }

  @override
  String toString() {
    return 'PlayerSelectionDetails(players: $players, checkoutRule: $checkoutRule, startingScore: $startingScore, randomOrder: $randomOrder)';
  }
}

/// Details for setting up a Cricket game
class CricketGameDetails {
  final List<String> players;
  final CricketVariant variant;
  final bool randomOrder;

  const CricketGameDetails({
    required this.players,
    required this.variant,
    required this.randomOrder,
  });

  /// Create a copy with updated values
  CricketGameDetails copyWith({
    List<String>? players,
    CricketVariant? variant,
    bool? randomOrder,
  }) {
    return CricketGameDetails(
      players: players ?? this.players,
      variant: variant ?? this.variant,
      randomOrder: randomOrder ?? this.randomOrder,
    );
  }

  @override
  String toString() {
    return 'CricketGameDetails(players: $players, variant: $variant, randomOrder: $randomOrder)';
  }
}
