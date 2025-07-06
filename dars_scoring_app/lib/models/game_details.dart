import 'app_enums.dart';
import '../data/possible_finishes.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Data classes for game setup and configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Details for setting up a traditional game (301, 501, 1001)
class PlayerSelectionDetails {

  const PlayerSelectionDetails({
    required this.players,
    required this.checkoutRule,
    required this.startingScore,
    required this.randomOrder,
  });
  final List<String> players;
  final CheckoutRule checkoutRule;
  final int startingScore;
  final bool randomOrder;

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

  const CricketGameDetails({
    required this.players,
    required this.variant,
    required this.randomOrder,
  });
  final List<String> players;
  final CricketVariant variant;
  final bool randomOrder;

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

/// Details for setting up a Donkey game
class DonkeyGameDetails {

  const DonkeyGameDetails({
    required this.players,
    required this.variant,
    required this.randomOrder,
  });
  final List<String> players;
  final DonkeyVariant variant;
  final bool randomOrder;

  /// Create a copy with updated values
  DonkeyGameDetails copyWith({
    List<String>? players,
    DonkeyVariant? variant,
    bool? randomOrder,
  }) {
    return DonkeyGameDetails(
      players: players ?? this.players,
      variant: variant ?? this.variant,
      randomOrder: randomOrder ?? this.randomOrder,
    );
  }

  @override
  String toString() {
    return 'DonkeyGameDetails(players: $players, variant: $variant, randomOrder: $randomOrder)';
  }
}

/// Details for setting up a Killer game
class KillerGameDetails {

  const KillerGameDetails({
    required this.players,
    required this.randomOrder,
  });
  final List<String> players;
  final bool randomOrder;

  /// Create a copy with updated values
  KillerGameDetails copyWith({
    List<String>? players,
    bool? randomOrder,
  }) {
    return KillerGameDetails(
      players: players ?? this.players,
      randomOrder: randomOrder ?? this.randomOrder,
    );
  }

  @override
  String toString() {
    return 'KillerGameDetails(players: $players, randomOrder: $randomOrder)';
  }
}
