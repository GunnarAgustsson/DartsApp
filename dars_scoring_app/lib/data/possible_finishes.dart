// ─────────────────────────────────────────────────────────────────────────────
/// Rules for how a player may finish a game
enum CheckoutRule {
  doubleOut,    // must finish on a double (including bull=50)
  extendedOut,  // must finish on a double or triple (or bull)
  exactOut,     // exact zero, any segment
  openFinish,   // any segment, sum >= remainingScore wins
}

// ─── Ranking helpers ────────────────────────────────────────────────────────

// A priority list of ideal double finishes (lower index = more preferred)
const List<int> _preferredDoubles = [
  40, 32, 24, 16, 8, 4, 12, 20, 28, 36, 6, 18, 10, 14, 38, 26, 22, 34, 30, 2
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
  // allow a 50 finish under double-out
  segments.add(MapEntry('DB', 50));
  segments.add(MapEntry('25', 25));
  segments.sort((a, b) => b.value.compareTo(a.value));

  bool validLast(MapEntry<String,int> seg, int total) {
    switch (rule) {
      case CheckoutRule.openFinish:
        return total >= remainingScore;
      case CheckoutRule.exactOut:
        return total == remainingScore;
      case CheckoutRule.doubleOut:
        // must finish on a double; treat DB (bull) as a valid double always
        if (total == remainingScore
            && (seg.key.startsWith('D') || seg.key == 'DB')) {
          return true;
        }
        return false;
      case CheckoutRule.extendedOut:
        return total == remainingScore
            && (seg.key.startsWith('D') || seg.key.startsWith('T'));
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

// Sort by (1) fewer darts, (2) preferred double finish, (3) more trebles
List<List<String>> rankCheckouts(List<List<String>> combos) {
  combos.sort((a, b) {
    // 1) Fewer darts first
    if (a.length != b.length) {
      return a.length.compareTo(b.length);
    }

    // 2) Preferred last‐dart double order
    final va = _scoreOf(a.last), vb = _scoreOf(b.last);
    final ia = _preferredDoubles.indexOf(va);
    final ib = _preferredDoubles.indexOf(vb);
    final pa = ia >= 0 ? ia : _preferredDoubles.length;
    final pb = ib >= 0 ? ib : _preferredDoubles.length;
    final d = pa.compareTo(pb);
    if (d != 0) {
      return d;
    }

    // 3) More trebles is better
    final ta = a.where((seg) => seg.startsWith('T')).length;
    final tb = b.where((seg) => seg.startsWith('T')).length;
    return tb.compareTo(ta);
  });
  return combos;
}

/// Returns the top [limit] checkout sequences (default 1), or `[]` if none.
/// Always picks the shortest possible finishes only.
List<List<String>> bestCheckouts(
  int remainingScore,
  int remainingDarts,
  CheckoutRule rule, {
  int limit = 1,
}) {
  for (var darts = 1; darts <= remainingDarts; darts++) {
    final combos = getAllCheckouts(remainingScore, darts, rule);
    if (combos.isEmpty) continue;

    combos.sort((a, b) {
      // 1) fewer darts
      if (a.length != b.length) {
        return a.length.compareTo(b.length);
      }

      // 2) rule‐specific priority
      if (rule == CheckoutRule.exactOut) {
        // segment‐type priority: T < Bull < D < Single
        int typePriority(String code) {
          if (code.startsWith('T')) return 0;
          if (code == 'DB' || code == '25') return 1;
          if (code.startsWith('D')) return 2;
          return 3; // all other 'S' (singles)
        }

        // last‐dart type
        final la = typePriority(a.last);
        final lb = typePriority(b.last);
        if (la != lb) return lb.compareTo(la);

        // first‐dart type
        final fa = typePriority(a[0]);
        final fb = typePriority(b[0]);
        if (fa != fb) return fb.compareTo(fa);

        // tie‐break by first‐dart value
        final va = _scoreOf(a[0]);
        final vb = _scoreOf(b[0]);
        return vb.compareTo(va);
      }

      if (rule == CheckoutRule.extendedOut) {
        // must finish on D or T (including DB) but prefer pure doubles > DB > trebles
        int finishPriority(String code) {
          if (code.startsWith('D') && code != 'DB') return 0; // normal doubles
          if (code == 'DB') return 1;                       // double bull
          if (code.startsWith('T')) return 2;                // trebles
          return 3;                                          // should not happen
        }

        final pa = finishPriority(a.last), pb = finishPriority(b.last);
        if (pa != pb) return pa.compareTo(pb);

        // same finish‐type, prefer higher‐value finish dart
        final la = _scoreOf(a.last), lb = _scoreOf(b.last);
        if (la != lb) return lb.compareTo(la);

        // tie-break: higher first-dart score
        final fa = _scoreOf(a[0]), fb = _scoreOf(b[0]);
        return fb.compareTo(fa);
      }

      // doubleOut & openFinish: existing logic …
      final va = _scoreOf(a.last), vb = _scoreOf(b.last);
      final ia = _preferredDoubles.indexOf(va);
      final ib = _preferredDoubles.indexOf(vb);
      final pa = ia >= 0 ? ia : _preferredDoubles.length;
      final pb = ib >= 0 ? ib : _preferredDoubles.length;
      final cmpD = pa.compareTo(pb);
      if (cmpD != 0) return cmpD;

      final ta = a.where((s) => s.startsWith('T')).length;
      final tb = b.where((s) => s.startsWith('T')).length;
      return tb.compareTo(ta);
    });

    return combos.take(limit).toList();
  }
  return <List<String>>[];
}
