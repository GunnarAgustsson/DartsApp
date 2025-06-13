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
// This order reflects standard preference in competitive darts
const List<int> _preferredDoubles = [
  40, 32, 16, 8, 4, 2, 36, 20, 10, 24, 12, 6, 18, 34, 30, 28, 26, 38, 14, 22
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
) {  // rebuild the segments list with standard dartboard priorities
  final segments = <MapEntry<String, int>>[];
  
  // For first dart in a sequence, we typically want higher values 
  // especially triples of high numbers like 20, 19, 18
  if (remainingDarts >= 2) {
    // Add T20 first (highest priority for first dart)
    segments.add(MapEntry('T20', 60));
    
    // Then other high-value triples in descending order
    for (var i = 19; i >= 10; i--) {
      segments.add(MapEntry('T$i', i * 3));
    }
    
    // Add remaining triples
    for (var i = 9; i >= 1; i--) {
      segments.add(MapEntry('T$i', i * 3));
    }
    
    // Then doubles in preferred order
    for (var i = 20; i >= 1; i--) {
      segments.add(MapEntry('D$i', i * 2));
    }
    
    // Singles last (except bulls)
    for (var i = 20; i >= 1; i--) {
      segments.add(MapEntry('S$i', i));
    }
    
    // Add bulls
    segments.add(MapEntry('DB', 50));
    segments.add(MapEntry('25', 25));
  } else {
    // For last dart, the order depends on rule
    // For doubleOut, doubles should be first
    if (rule == CheckoutRule.doubleOut) {
      // Add preferred doubles first
      for (var d in _preferredDoubles) {
        segments.add(MapEntry('D${d~/2}', d));
      }
      
      // Add any remaining doubles
      for (var i = 20; i >= 1; i--) {
        if (!_preferredDoubles.contains(i * 2)) {
          segments.add(MapEntry('D$i', i * 2));
        }
      }
      
      // Bull counts as a double
      segments.add(MapEntry('DB', 50));
    } else {
      // For other rules, add all segments
      for (var i = 20; i >= 1; i--) {
        segments.add(MapEntry('T$i', i * 3));
        segments.add(MapEntry('D$i', i * 2));
        segments.add(MapEntry('S$i', i));
      }
      segments.add(MapEntry('DB', 50));
      segments.add(MapEntry('25', 25));
    }
  }
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
      }      if (rule == CheckoutRule.openFinish) {
        // For openFinish, prioritize combinations that are closest to the score
        int totalA = a.fold(0, (sum, s) => sum + _scoreOf(s));
        int totalB = b.fold(0, (sum, s) => sum + _scoreOf(s));
        
        // First compare based on how close the total is to the remainingScore
        if (totalA != totalB) {
          // We want the score that's just over or exactly at the target
          if (totalA >= remainingScore && totalB >= remainingScore) {
            // Both are over, pick the one that's closer to the score
            return totalA.compareTo(totalB);
          } else {
            // At least one is under - prefer the higher one
            return totalB.compareTo(totalA);
          }
        }
        
        // If totals are the same, prefer more trebles
        final ta = a.where((s) => s.startsWith('T')).length;
        final tb = b.where((s) => s.startsWith('T')).length;
        return tb.compareTo(ta);
      }
      
      // doubleOut logic - prioritize standard checkout paths
      if (rule == CheckoutRule.doubleOut) {
        // 1. First check if this is a standard checkout for common numbers
        final int totalA = a.fold(0, (sum, s) => sum + _scoreOf(s));
        final int totalB = b.fold(0, (sum, s) => sum + _scoreOf(s));
        
        // Common checkout paths that should be preferred
        final Map<int, List<String>> standardCheckouts = {
          170: ['T20', 'T20', 'DB'],
          167: ['T20', 'T19', 'DB'],
          164: ['T20', 'T18', 'DB'],
          161: ['T20', 'T17', 'DB'],
          160: ['T20', 'T20', 'D20'],
          // ... more standard checkouts ...
          121: ['T20', 'S11', 'DB'],
          120: ['T20', 'D20'],
          119: ['T19', 'S12', 'D20'],
          118: ['T20', 'D19'],
          117: ['T19', 'D20'],
          116: ['T20', 'D18'],
          115: ['T19', 'D19'],
          114: ['T20', 'D17'],
          113: ['T19', 'D18'],
          112: ['T20', 'D16'],
          111: ['T19', 'D17'],
          110: ['T20', 'DB'],
          107: ['T19', 'DB'],
          104: ['T18', 'DB'],
          101: ['T17', 'DB'],
          100: ['T20', 'D20'],
          99: ['T19', 'D21'],
          98: ['T20', 'D19'],
          97: ['T19', 'D20'],
          96: ['T20', 'D18'],
          95: ['T19', 'D19'],
          94: ['T18', 'D20'],
          93: ['T19', 'D18'],
          92: ['T20', 'D16'],
          91: ['T17', 'D20'],
          90: ['T20', 'D15'],
          89: ['T19', 'D16'],
          86: ['T18', 'D16'],
          85: ['T15', 'D20'],
          84: ['T20', 'D12'],
          83: ['T17', 'D16'],
          82: ['T14', 'D20'],
          81: ['T19', 'D12'],
          80: ['T20', 'D10'],
          79: ['T19', 'D11'],
          78: ['T18', 'D12'],
          77: ['T19', 'D10'],
          76: ['T20', 'D8'],
          75: ['T17', 'D12'],
          74: ['T14', 'D16'],
          73: ['T19', 'D8'],
          72: ['T16', 'D12'],
          71: ['T13', 'D16'],
          70: ['T18', 'D8'],
          69: ['T19', 'D6'],
          68: ['T20', 'D4'],
          67: ['T17', 'D8'],
          66: ['T14', 'D12'],
          65: ['T19', 'D4'],
          64: ['T16', 'D8'],
          63: ['T17', 'D6'],
          62: ['T10', 'D16'],
          61: ['T15', 'D8'],
          60: ['D20', 'D20'],
          58: ['D19', 'D20'],
          56: ['T16', 'D4'],
          54: ['T14', 'D6'],
          52: ['T12', 'D8'],
          50: ['DB'],
          40: ['D20'],
          38: ['D19'],
          36: ['D18'],
          34: ['D17'],
          32: ['D16'],
          30: ['D15'],
          28: ['D14'],
          26: ['D13'],
          24: ['D12'],
          22: ['D11'],
          20: ['D10'],
          18: ['D9'],
          16: ['D8'],
          14: ['D7'],
          12: ['D6'],
          10: ['D5'],
          8: ['D4'],
          6: ['D3'],
          4: ['D2'],
          2: ['D1'],
        };
        
        // 2. Check if a standard checkout exists and use it if found
        if (standardCheckouts.containsKey(totalA) && 
            a.join(' ') == standardCheckouts[totalA]!.join(' ')) {
          return -1;
        }
        if (standardCheckouts.containsKey(totalB) && 
            b.join(' ') == standardCheckouts[totalB]!.join(' ')) {
          return 1;
        }
        
        // 3. For shots that don't have a standard pattern listed above
        
        // Prefer paths with the highest scoring first dart
        if (a.isNotEmpty && b.isNotEmpty) {
          final firstDartValueA = _scoreOf(a[0]);
          final firstDartValueB = _scoreOf(b[0]);
          
          // T20 is the most preferred first dart in double-out
          if (a[0] == 'T20' && b[0] != 'T20') return -1;
          if (a[0] != 'T20' && b[0] == 'T20') return 1;
          
          if (firstDartValueA != firstDartValueB) {
            return firstDartValueB.compareTo(firstDartValueA);
          }
        }
        
        // Then check for preferred doubles at the end
        final va = _scoreOf(a.last), vb = _scoreOf(b.last);
        final ia = _preferredDoubles.indexOf(va);
        final ib = _preferredDoubles.indexOf(vb);
        final pa = ia >= 0 ? ia : _preferredDoubles.length;
        final pb = ib >= 0 ? ib : _preferredDoubles.length;
        if (pa != pb) return pa.compareTo(pb);
        
        // Lastly prefer paths with more trebles
        final ta = a.where((s) => s.startsWith('T')).length;
        final tb = b.where((s) => s.startsWith('T')).length;
        return tb.compareTo(ta);
      }
      
      // Default sorting logic for other cases
      int trebleCountA = a.where((s) => s.startsWith('T')).length;
      int trebleCountB = b.where((s) => s.startsWith('T')).length;
      return trebleCountB.compareTo(trebleCountA);
    });

    return combos.take(limit).toList();
  }
  return <List<String>>[];
}
