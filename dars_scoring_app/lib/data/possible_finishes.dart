// ─────────────────────────────────────────────────────────────────────────────
/// Rules for how a player may finish a game
enum CheckoutRule {
  doubleOut,    // must finish on a double (including bull=50)
  extendedOut,  // must finish on a double or triple (or bull)
  exactOut,     // exact zero, any segment
  openFinish,   // any segment, sum >= remainingScore wins
}

// ─────────────────────────────────────────────────────────────────────────────
/// Attempts to find a sequence of up to [remainingDarts] throws that
/// lets you finish [remainingScore] under [rule].
/// Returns a list of segment codes (e.g. ["T20","T20","D5"]) if found,
/// or null if no legal checkout exists.
List<String>? calculateCheckout(
  int remainingScore,
  int remainingDarts,
  CheckoutRule rule,
) {
  // 1) Build all possible segments: triples, doubles, singles, bull(50), outer bull(25)
  final segments = <MapEntry<String, int>>[];
  for (var i = 1; i <= 20; i++) {
    segments.add(MapEntry('T$i', 3 * i));
    segments.add(MapEntry('D$i', 2 * i));
    segments.add(MapEntry('S$i', i));
  }
  segments.add(MapEntry('D25', 50));
  segments.add(MapEntry('S25', 25));
  // Sort descending so we try high‐value finishes first
  segments.sort((a, b) => b.value.compareTo(a.value));

  // 2) Helper: check if a final segment [code,value] satisfies [rule]
  bool _validLast(MapEntry<String,int> seg, int total) {
    switch (rule) {
      case CheckoutRule.openFinish:
        // any finish that reaches or exceeds target
        return total >= remainingScore;
      case CheckoutRule.exactOut:
        // exact match to zero
        return total == remainingScore;
      case CheckoutRule.doubleOut:
        // exact zero on a double or bull
        return total == remainingScore
            && (seg.key.startsWith('D'));
      case CheckoutRule.extendedOut:
        // exact zero on double, triple, or bull
        return total == remainingScore
            && (seg.key.startsWith('D') || seg.key.startsWith('T'));
    }
  }

  // 3) Try 1‐dart combos
  if (remainingDarts >= 1) {
    for (var s1 in segments) {
      final sum1 = s1.value;
      if (_validLast(s1, sum1)) {
        return [s1.key];
      }
    }
  }

  // 4) Try 2‐dart combos
  if (remainingDarts >= 2) {
    for (var s1 in segments) {
      for (var s2 in segments) {
        final sum2 = s1.value + s2.value;
        if (_validLast(s2, sum2)) {
          return [s1.key, s2.key];
        }
      }
    }
  }

  // 5) Try 3‐dart combos
  if (remainingDarts >= 3) {
    for (var s1 in segments) {
      for (var s2 in segments) {
        for (var s3 in segments) {
          final sum3 = s1.value + s2.value + s3.value;
          if (_validLast(s3, sum3)) {
            return [s1.key, s2.key, s3.key];
          }
        }
      }
    }
  }

  // No legal checkout found
  return null;
}
