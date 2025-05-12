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
  bool validLast(MapEntry<String,int> seg, int total) {
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
      if (validLast(s1, sum1)) {
        return [s1.key];
      }
    }
  }

  // 4) Try 2‐dart combos
  if (remainingDarts >= 2) {
    for (var s1 in segments) {
      for (var s2 in segments) {
        final sum2 = s1.value + s2.value;
        if (validLast(s2, sum2)) {
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
          if (validLast(s3, sum3)) {
            return [s1.key, s2.key, s3.key];
          }
        }
      }
    }
  }

  // No legal checkout found
  return null;
}

// ─── Ranking helpers ────────────────────────────────────────────────────────

// A priority list of ideal double finishes (lower index = more preferred)
const List<int> _preferredDoubles = [
  32, 16, 8, 40, 24, 36, 20, 12, 28, 10, 4, 2, 6, 18, 14, 38, 26, 22, 34, 30
];

// Parse a segment code into its score
int _scoreOf(String code) {
  if (code == 'DB') return 50;
  if (code == 'SB') return 25;
  final num = int.parse(code.substring(1));
  switch (code[0]) {
    case 'T': return num * 3;
    case 'D': return num * 2;
    case 'S': return num;
    default:  return 0;
  }
}

// Collect *all* legal checkout combos up to [remainingDarts]
List<List<String>> getAllCheckouts(
  int remainingScore,
  int remainingDarts,
  CheckoutRule rule,
) {
  // rebuild the same segments list
  final segments = <MapEntry<String, int>>[];
  for (var i = 1; i <= 20; i++) {
    segments.add(MapEntry('T$i', i * 3));
    segments.add(MapEntry('D$i', i * 2));
    segments.add(MapEntry('S$i', i));
  }
  segments.add(MapEntry('D25', 50));
  segments.add(MapEntry('S25', 25));
  segments.sort((a, b) => b.value.compareTo(a.value));

  bool validLast(MapEntry<String,int> seg, int total) {
    switch (rule) {
      case CheckoutRule.openFinish:  return total >= remainingScore;
      case CheckoutRule.exactOut:    return total == remainingScore;
      case CheckoutRule.doubleOut:   return total == remainingScore && seg.key.startsWith('D');
      case CheckoutRule.extendedOut: return total == remainingScore && (seg.key.startsWith('D') || seg.key.startsWith('T'));
    }
  }

  final results = <List<String>>[];
  if (remainingDarts >= 1) {
    for (var s1 in segments) {
      if (validLast(s1, s1.value)) results.add([s1.key]);
    }
  }
  if (remainingDarts >= 2) {
    for (var s1 in segments) {
      for (var s2 in segments) {
        final sum2 = s1.value + s2.value;
        if (validLast(s2, sum2)) results.add([s1.key, s2.key]);
      }
    }
  }
  if (remainingDarts >= 3) {
    for (var s1 in segments) {
      for (var s2 in segments) {
        for (var s3 in segments) {
          final sum3 = s1.value + s2.value + s3.value;
          if (validLast(s3, sum3)) results.add([s1.key, s2.key, s3.key]);
        }
      }
    }
  }
  return results;
}

// Sort by (1) preferred double finish, (2) fewer darts, (3) fewer trebles
List<List<String>> rankCheckouts(List<List<String>> combos) {
  combos.sort((a, b) {
    final pa = _preferredDoubles.indexOf(_scoreOf(a.last)).clamp(0, _preferredDoubles.length);
    final pb = _preferredDoubles.indexOf(_scoreOf(b.last)).clamp(0, _preferredDoubles.length);
    final cmpD = pa.compareTo(pb);
    if (cmpD != 0) return cmpD;
    if (a.length != b.length) return a.length.compareTo(b.length);
    final ta = a.where((seg) => seg.startsWith('T')).length;
    final tb = b.where((seg) => seg.startsWith('T')).length;
    return ta.compareTo(tb);
  });
  return combos;
}

/// Returns the top [limit] checkout sequences (default 3), or `[]` if none.
List<List<String>> bestCheckouts(
  int remainingScore,
  int remainingDarts,
  CheckoutRule rule, {
  int limit = 3,
}) {
  final all = getAllCheckouts(remainingScore, remainingDarts, rule);
  if (all.isEmpty) return [];
  final ranked = rankCheckouts(all);
  return ranked.take(limit).toList();
}
