// ─────────────────────────────────────────────────────────────────────────────
/// App-wide enums for the Darts Scoring App
// ─────────────────────────────────────────────────────────────────────────────

/// Cricket game variants available
library;

enum CricketVariant {
  standard,   // Standard Cricket (20-15, Bull)
  noScore,    // Race Cricket (no scoring, first to close wins)
  simplified  // Quick Cricket (20, 19, 18 only)
}

/// Donkey game variants (HORSE-style game)
enum DonkeyVariant {
  oneDart,   // One dart per turn - quick gameplay
  threeDart  // Three darts per turn - more strategic
}

/// Animation speed options for the app
enum AnimationSpeed {
  none,     // Instant updates, no animations
  slow,     // Slower animations for better visibility
  normal,   // Default animation speed
  fast      // Quick animations for faster gameplay
}

/// Traditional game variants (301, 501, 1001)
enum TraditionalVariant {
  game301,
  game501,
  game1001
}

// ─────────────────────────────────────────────────────────────────────────────
/// Helper extensions for enums
// ─────────────────────────────────────────────────────────────────────────────

extension CricketVariantExtension on CricketVariant {
  String get title {
    switch (this) {
      case CricketVariant.standard:
        return 'Standard Cricket';
      case CricketVariant.noScore:
        return 'Race Cricket';
      case CricketVariant.simplified:
        return 'Quick Cricket';
    }
  }

  String get description {
    switch (this) {
      case CricketVariant.standard:
        return 'Close all numbers (20-15, Bull) and score points. Win by closing all with highest score.';
      case CricketVariant.noScore:
        return 'Close all numbers (20-15, Bull). First to close all numbers wins - no scoring.';      case CricketVariant.simplified:
        return 'Close 20, 19, 18. First to close all three numbers wins - no scoring.';
    }
  }
}

extension DonkeyVariantExtension on DonkeyVariant {
  String get title {
    switch (this) {
      case DonkeyVariant.oneDart:
        return 'One Dart Donkey';
      case DonkeyVariant.threeDart:
        return 'Three Dart Donkey';
    }
  }

  String get description {
    switch (this) {
      case DonkeyVariant.oneDart:
        return 'Beat the previous score with one dart. First to spell DONKEY loses.';
      case DonkeyVariant.threeDart:
        return 'Beat the previous score with up to three darts. First to spell DONKEY loses.';
    }
  }

  int get dartsPerTurn {
    switch (this) {
      case DonkeyVariant.oneDart:
        return 1;
      case DonkeyVariant.threeDart:
        return 3;
    }
  }
}

extension AnimationSpeedExtension on AnimationSpeed {
  String get title {
    switch (this) {
      case AnimationSpeed.none:
        return 'None';
      case AnimationSpeed.slow:
        return 'Slow';
      case AnimationSpeed.normal:
        return 'Normal';
      case AnimationSpeed.fast:
        return 'Fast';
    }
  }

  String get description {
    switch (this) {
      case AnimationSpeed.none:
        return 'Instant updates with no animations';
      case AnimationSpeed.slow:
        return 'Slower animations for better visibility';
      case AnimationSpeed.normal:
        return 'Default animation speed';
      case AnimationSpeed.fast:
        return 'Quick animations for faster gameplay';
    }
  }

  /// Get the duration in milliseconds for this animation speed
  int get durationMs {
    switch (this) {
      case AnimationSpeed.none:
        return 0;
      case AnimationSpeed.slow:
        return 2000;
      case AnimationSpeed.normal:
        return 1000;
      case AnimationSpeed.fast:
        return 500;
    }
  }

  /// Get the Duration object for this animation speed
  Duration get duration => Duration(milliseconds: durationMs);
}

extension TraditionalVariantExtension on TraditionalVariant {
  String get title {
    switch (this) {
      case TraditionalVariant.game301:
        return '301';
      case TraditionalVariant.game501:
        return '501';
      case TraditionalVariant.game1001:
        return '1001';
    }
  }

  String get description {
    switch (this) {
      case TraditionalVariant.game301:
        return 'Quick traditional game starting from 301 points';
      case TraditionalVariant.game501:
        return 'Standard traditional game starting from 501 points';
      case TraditionalVariant.game1001:
        return 'Long traditional game starting from 1001 points';
    }
  }

  int get startingScore {
    switch (this) {
      case TraditionalVariant.game301:
        return 301;
      case TraditionalVariant.game501:
        return 501;
      case TraditionalVariant.game1001:
        return 1001;
    }
  }
}
