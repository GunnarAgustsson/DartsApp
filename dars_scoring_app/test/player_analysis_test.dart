import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Test suite for player analysis and statistics calculations
/// Tests the core logic from PlayerInfoScreen._loadStats() and _calculateAdvancedStats()
void main() {
  group('Player Analysis Tests', () {
    late SharedPreferences prefs;
    
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    
    test('Basic stats calculation - single completed game', () async {
      // Create a simple completed game with known throws
      final gameData = {
        'id': 'test-1',
        'gameMode': 501,
        'players': ['Alice', 'Bob'],
        'winner': 'Alice',
        'createdAt': '2024-01-01T10:00:00Z',
        'completedAt': '2024-01-01T10:30:00Z',
        'throws': [
          // Alice throws (3 rounds = 9 darts)
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 441, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 381, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 321, 'wasBust': false},
          // Bob throws
          {'player': 'Bob', 'value': 15, 'multiplier': 1, 'resultingScore': 486, 'wasBust': false},
          {'player': 'Bob', 'value': 15, 'multiplier': 1, 'resultingScore': 471, 'wasBust': false},
          {'player': 'Bob', 'value': 15, 'multiplier': 1, 'resultingScore': 456, 'wasBust': false},
          // Alice throws
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 264, 'wasBust': false},
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 207, 'wasBust': false},
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 150, 'wasBust': false},
          // Bob throws
          {'player': 'Bob', 'value': 16, 'multiplier': 1, 'resultingScore': 440, 'wasBust': false},
          {'player': 'Bob', 'value': 16, 'multiplier': 1, 'resultingScore': 424, 'wasBust': false},
          {'player': 'Bob', 'value': 16, 'multiplier': 1, 'resultingScore': 408, 'wasBust': false},
          // Alice wins with checkout
          {'player': 'Alice', 'value': 25, 'multiplier': 2, 'resultingScore': 100, 'wasBust': false},
          {'player': 'Alice', 'value': 25, 'multiplier': 2, 'resultingScore': 50, 'wasBust': false},
          {'player': 'Alice', 'value': 25, 'multiplier': 2, 'resultingScore': 0, 'wasBust': false}, // Checkout on DB
        ]
      };
      
      await prefs.setStringList('games_history', [jsonEncode(gameData)]);
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      // Basic stats verification
      expect(stats['totalGamesPlayed'], 1);
      expect(stats['totalWins'], 1);
      expect(stats['winRate'], 100.0);
      
      // Alice's throws: 60, 60, 60, 57, 57, 57, 50, 50, 50 = 501 total, 9 throws
      expect(stats['avgScore'], closeTo(55.67, 0.1)); // 501/9 ≈ 55.67
      
      // Best leg should be 9 darts (Alice won in 9 darts)
      expect(stats['bestLegDarts'], 9);
      
      // Highest checkout should be 50 (double bull)
      expect(stats['highestCheckout'], 50.0);
      
      // Most hit number should be 20 (hit 3 times)
      expect(stats['mostHitNumber'], 20);
      expect(stats['mostHitCount'], 3);
    });
    
    test('Win rate calculation with mixed results', () async {
      final games = [
        // Win 1
        {
          'id': 'test-1',
          'gameMode': 501,
          'players': ['Alice', 'Bob'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T10:00:00Z',
          'completedAt': '2024-01-01T10:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 0, 'wasBust': false},
          ]
        },
        // Loss 1
        {
          'id': 'test-2',
          'gameMode': 501, 
          'players': ['Alice', 'Bob'],
          'winner': 'Bob',
          'createdAt': '2024-01-01T11:00:00Z',
          'completedAt': '2024-01-01T11:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 15, 'multiplier': 1, 'resultingScore': 100, 'wasBust': false},
          ]
        },
        // Win 2
        {
          'id': 'test-3',
          'gameMode': 501,
          'players': ['Alice', 'Bob'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T12:00:00Z', 
          'completedAt': '2024-01-01T12:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 20, 'multiplier': 2, 'resultingScore': 0, 'wasBust': false},
          ]
        },
        // In progress (should not count)
        {
          'id': 'test-4',
          'gameMode': 501,
          'players': ['Alice', 'Bob'],
          'winner': null,
          'createdAt': '2024-01-01T13:00:00Z',
          'completedAt': null,
          'throws': [
            {'player': 'Alice', 'value': 10, 'multiplier': 1, 'resultingScore': 400, 'wasBust': false},
          ]
        }
      ];
      
      await prefs.setStringList('games_history', games.map(jsonEncode).toList());
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      expect(stats['totalGamesPlayed'], 3); // Only completed games
      expect(stats['totalWins'], 2);
      expect(stats['winRate'], closeTo(66.67, 0.1)); // 2/3 * 100 ≈ 66.67
    });
    
    test('Checkout efficiency calculation', () async {
      final gameData = {
        'id': 'test-1',
        'gameMode': 501,
        'players': ['Alice'],
        'winner': 'Alice',
        'completedAt': '2024-01-01T10:00:00Z',
        'throws': [
          // Score down to checkout range
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 441, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 381, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 321, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 261, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 201, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 141, 'wasBust': false},
          // Now in checkout range (≤ 170)
          {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 121, 'wasBust': false}, // Miss
          {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 101, 'wasBust': false}, // Miss  
          {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 81, 'wasBust': false},  // Miss
          {'player': 'Alice', 'value': 19, 'multiplier': 1, 'resultingScore': 62, 'wasBust': false}, // Miss
          {'player': 'Alice', 'value': 12, 'multiplier': 2, 'resultingScore': 38, 'wasBust': false}, // Miss
          {'player': 'Alice', 'value': 19, 'multiplier': 2, 'resultingScore': 0, 'wasBust': false},  // Success!
        ]
      };
      
      await prefs.setStringList('games_history', [jsonEncode(gameData)]);
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      // From 141 (checkout range), Alice had 6 attempts and 1 success
      // Efficiency should be 1/6 * 100 ≈ 16.67%
      expect(stats['checkoutEfficiency'], closeTo(16.67, 0.1));
      expect(stats['favoriteCheckout'], 'D19'); // The successful checkout
    });
    
    test('Hit heatmap and segment distribution', () async {
      final gameData = {
        'id': 'test-1',
        'gameMode': 501,
        'players': ['Alice'],
        'winner': null,
        'createdAt': '2024-01-01T10:00:00Z',
        'completedAt': '2024-01-01T10:00:00Z',
        'throws': [
          // Mix of singles, doubles, triples, and bulls
          {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 400, 'wasBust': false}, // Single
          {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 380, 'wasBust': false}, // Single
          {'player': 'Alice', 'value': 19, 'multiplier': 2, 'resultingScore': 342, 'wasBust': false}, // Double
          {'player': 'Alice', 'value': 18, 'multiplier': 3, 'resultingScore': 288, 'wasBust': false}, // Triple
          {'player': 'Alice', 'value': 25, 'multiplier': 1, 'resultingScore': 263, 'wasBust': false}, // Single bull
          {'player': 'Alice', 'value': 50, 'multiplier': 1, 'resultingScore': 213, 'wasBust': false}, // Double bull
          {'player': 'Alice', 'value': 15, 'multiplier': 1, 'resultingScore': 198, 'wasBust': false}, // Single
          // Add a bust to verify it's excluded
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 198, 'wasBust': true},  // Bust (excluded)
        ]
      };
      
      await prefs.setStringList('games_history', [jsonEncode(gameData)]);
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      // Verify hit counts (excluding bust)
      final hitHeatmap = stats['hitHeatmap'] as Map<int, int>;
      expect(hitHeatmap[20], 2); // Two single 20s
      expect(hitHeatmap[19], 1); // One double 19
      expect(hitHeatmap[18], 1); // One triple 18
      expect(hitHeatmap[15], 1); // One single 15
      expect(hitHeatmap[25], 1); // Single bull
      expect(hitHeatmap[50], 1); // Double bull
      
      // Most hit should be 20 (appears twice)
      expect(stats['mostHitNumber'], 20);
      expect(stats['mostHitCount'], 2);
      
      // Segment distribution
      expect(stats['countSingles'], 3); // 20, 20, 15 (not counting bulls)
      expect(stats['countDoubles'], 1); // 19*2
      expect(stats['countTriples'], 1); // 18*3
      expect(stats['countBulls'], 2);   // 25, 50
    });
    
    test('First 9 average calculation', () async {
      final gameData = {
        'id': 'test-1',
        'gameMode': 501,
        'players': ['Alice'],
        'winner': 'Alice',
        'createdAt': '2024-01-01T10:00:00Z',
        'completedAt': '2024-01-01T10:00:00Z',
        'throws': [
          // First 9 darts: mix of values
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 441, 'wasBust': false}, // 60
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 381, 'wasBust': false}, // 60
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 321, 'wasBust': false}, // 60
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 264, 'wasBust': false}, // 57
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 207, 'wasBust': false}, // 57
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 150, 'wasBust': false}, // 57
          {'player': 'Alice', 'value': 18, 'multiplier': 3, 'resultingScore': 96, 'wasBust': false},  // 54
          {'player': 'Alice', 'value': 18, 'multiplier': 3, 'resultingScore': 42, 'wasBust': false},  // 54
          {'player': 'Alice', 'value': 21, 'multiplier': 2, 'resultingScore': 0, 'wasBust': false},   // 42
          // These throws after 9th dart should not count for first 9 average
          {'player': 'Alice', 'value': 1, 'multiplier': 1, 'resultingScore': 0, 'wasBust': false},
          {'player': 'Alice', 'value': 1, 'multiplier': 1, 'resultingScore': 0, 'wasBust': false},
        ]
      };
      
      await prefs.setStringList('games_history', [jsonEncode(gameData)]);
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      // First 9 total: 60+60+60+57+57+57+54+54+42 = 501
      // First 9 average: 501/9 = 55.67
      expect(stats['first9Average'], closeTo(55.67, 0.1));
    });
    
    test('Consistency rating calculation', () async {
      // Create multiple games with varying averages to test consistency
      final games = [
        {
          'id': 'test-1',
          'gameMode': 501,
          'players': ['Alice'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T10:00:00Z',
          'completedAt': '2024-01-01T10:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 0, 'wasBust': false}, // Avg: 20
          ]
        },
        {
          'id': 'test-2',
          'gameMode': 501, 
          'players': ['Alice'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T11:00:00Z',
          'completedAt': '2024-01-01T11:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 0, 'wasBust': false}, // Avg: 20
          ]
        },
        {
          'id': 'test-3',
          'gameMode': 501,
          'players': ['Alice'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T12:00:00Z',
          'completedAt': '2024-01-01T12:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 0, 'wasBust': false}, // Avg: 20
          ]
        }
      ];
      
      await prefs.setStringList('games_history', games.map(jsonEncode).toList());
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      // Perfect consistency (no variance) should result in 100% consistency rating
      expect(stats['consistencyRating'], closeTo(100.0, 0.1));
    });
    
    test('Largest round and bust score tracking', () async {
      final gameData = {
        'id': 'test-1',
        'gameMode': 501,
        'players': ['Alice'],
        'winner': 'Alice',
        'createdAt': '2024-01-01T10:00:00Z',
        'completedAt': '2024-01-01T10:00:00Z',
        'throws': [
          // Round 1: 60 + 60 + 60 = 180 (should be largest round)
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 441, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 381, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 321, 'wasBust': false},
          // Round 2: 57 + 57 + 40 = 154
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 264, 'wasBust': false},
          {'player': 'Alice', 'value': 19, 'multiplier': 3, 'resultingScore': 207, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 2, 'resultingScore': 167, 'wasBust': false},
          // Round 3: Bust round - 60 + 60 + bust = should track as 120 bust
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 107, 'wasBust': false},
          {'player': 'Alice', 'value': 20, 'multiplier': 3, 'resultingScore': 47, 'wasBust': false},
          {'player': 'Alice', 'value': 25, 'multiplier': 2, 'resultingScore': 47, 'wasBust': true}, // Bust
        ]
      };
      
      await prefs.setStringList('games_history', [jsonEncode(gameData)]);
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      expect(stats['largestRoundScore'], 180); // First round total
      expect(stats['largestBustScore'], 170);  // Bust round total (60+60+50)
    });
    
    test('Handles empty player history gracefully', () async {
      await prefs.setStringList('games_history', []);
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      expect(stats['totalGamesPlayed'], 0);
      expect(stats['totalWins'], 0);
      expect(stats['winRate'], 0.0);
      expect(stats['avgScore'], 0.0);
      expect(stats['bestLegDarts'], 0);
      expect(stats['highestCheckout'], 0.0);
      expect(stats['checkoutEfficiency'], 0.0);
      expect(stats['first9Average'], 0.0);
      expect(stats['consistencyRating'], 0.0);
    });
    
    test('Ignores incomplete games in statistics', () async {
      final games = [
        // Completed game
        {
          'id': 'test-1',
          'gameMode': 501,
          'players': ['Alice'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T10:00:00Z',
          'completedAt': '2024-01-01T10:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 20, 'multiplier': 1, 'resultingScore': 0, 'wasBust': false},
          ]
        },
        // Incomplete game (should be ignored)
        {
          'id': 'test-2',
          'gameMode': 501,
          'players': ['Alice'],
          'winner': null,
          'createdAt': '2024-01-01T11:00:00Z',
          'completedAt': null,
          'throws': [
            {'player': 'Alice', 'value': 1, 'multiplier': 1, 'resultingScore': 500, 'wasBust': false},
          ]
        }
      ];
      
      await prefs.setStringList('games_history', games.map(jsonEncode).toList());
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      // Should only count the completed game
      expect(stats['totalGamesPlayed'], 1);
      expect(stats['avgScore'], 20.0); // Only count the 20 from completed game
    });

    test('Favorite checkout tracks most frequent finishing dart', () async {
      final games = [
        // Game 1: Finish with Double 16
        {
          'id': 'test-1',
          'gameMode': 501,
          'players': ['Alice'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T10:00:00Z',
          'completedAt': '2024-01-01T10:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 16, 'multiplier': 2, 'resultingScore': 0, 'wasBust': false},
          ]
        },
        // Game 2: Finish with Double 16 again
        {
          'id': 'test-2',
          'gameMode': 501,
          'players': ['Alice'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T11:00:00Z',
          'completedAt': '2024-01-01T11:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 16, 'multiplier': 2, 'resultingScore': 0, 'wasBust': false},
          ]
        },
        // Game 3: Finish with Double 20 (less frequent)
        {
          'id': 'test-3',
          'gameMode': 501,
          'players': ['Alice'],
          'winner': 'Alice',
          'createdAt': '2024-01-01T12:00:00Z',
          'completedAt': '2024-01-01T12:00:00Z',
          'throws': [
            {'player': 'Alice', 'value': 20, 'multiplier': 2, 'resultingScore': 0, 'wasBust': false},
          ]
        }
      ];
      
      await prefs.setStringList('games_history', games.map(jsonEncode).toList());
      
      final stats = await _calculatePlayerStats('Alice', prefs);
      
      // D16 appears twice, D20 appears once, so D16 should be favorite
      expect(stats['favoriteCheckout'], 'D16');
    });
  });
}

/// Simulates the core statistics calculation logic from PlayerInfoScreen
/// This extracts and tests the statistical calculations without UI dependencies
Future<Map<String, dynamic>> _calculatePlayerStats(String playerName, SharedPreferences prefs) async {
  final games = prefs.getStringList('games_history') ?? [];
  
  // Initialize counters
  int totalGames = 0;
  int wins = 0;
  List<int> allScores = [];
  Map<int, int> hitHeatmap = {};
  double maxCheckout = 0;
  int minDarts = 9999;
  Map<int, int> hitCount = {};
  int singles = 0, doubles = 0, triples = 0, bulls = 0;
  int largestRound = 0;
  int largestBust = 0;
  
  // Advanced stats
  List<int> first9Scores = [];
  Map<String, int> checkoutRoutes = {};
  List<double> allGameAverages = [];
  int checkoutAttempts = 0;
  int checkoutSuccesses = 0;
  
  // Count only completed games for win rate
  for (final g in games.reversed) {
    final game = jsonDecode(g);
    if (!(game['players'] as List).contains(playerName)) continue;
    if (game['completedAt'] == null) continue;
    totalGames++;
    if (game['winner'] == playerName) wins++;
  }
  
  // Process completed games for detailed stats
  for (final g in games.reversed) {
    final game = jsonDecode(g);
    if (!(game['players'] as List).contains(playerName)) continue;
    if (game['completedAt'] == null) continue;
    
    final throws = (game['throws'] as List)
        .where((t) => t['player'] == playerName)
        .toList();
    
    // Best leg calculation
    if (game['winner'] == playerName) {
      final dartsThrown = throws.length;
      if (dartsThrown > 0 && dartsThrown < minDarts) {
        minDarts = dartsThrown;
      }
    }
    
    // Process individual throws
    for (int i = 0; i < throws.length; i++) {
      final t = throws[i];
      if (t['wasBust'] == true) continue;
      
      final value = (t['value'] ?? 0) as int;
      final multiplier = (t['multiplier'] ?? 1) as int;
      final score = value * multiplier;
      
      allScores.add(score);
      hitHeatmap[value] = (hitHeatmap[value] ?? 0) + 1;
      hitCount[value] = (hitCount[value] ?? 0) + 1;
      
      // Segment distribution
      if (value == 25 || value == 50) {
        bulls++;
      } else if (multiplier == 3) {
        triples++;
      } else if (multiplier == 2) {
        doubles++;
      } else {
        singles++;
      }
    }
    
    // Checkout tracking
    if (throws.isNotEmpty && throws.last['resultingScore'] == 0) {
      final lastThrow = throws.last;
      final value = lastThrow['value'] as int;
      final multiplier = lastThrow['multiplier'] as int;
      final checkout = (value * multiplier).toDouble();
      
      if (checkout > maxCheckout) {
        maxCheckout = checkout;
      }
      
      // Record checkout route
      String route;
      if (value == 50) {
        route = 'DB';
      } else if (value == 25) {
        route = 'SB';
      } else if (multiplier == 3) {
        route = 'T$value';
      } else if (multiplier == 2) {
        route = 'D$value';
      } else {
        route = 'S$value';
      }
      checkoutRoutes[route] = (checkoutRoutes[route] ?? 0) + 1;
    }
    
    // Checkout efficiency
    for (int i = 0; i < throws.length; i++) {
      final t = throws[i];
      final score = t['resultingScore'] as int;
      final prevScore = i > 0 ? throws[i-1]['resultingScore'] as int : game['gameMode'] as int;
      
      if (prevScore <= 170 && prevScore > 0) {
        checkoutAttempts++;
        if (score == 0) {
          checkoutSuccesses++;
        }
      }
    }
    
    // First 9 average
    final first9 = throws.take(9).toList();
    if (first9.isNotEmpty) {
      final first9Total = first9.fold<int>(0, (sum, t) => 
        sum + (t['wasBust'] == true ? 0 : ((t['value'] ?? 0) as int) * ((t['multiplier'] ?? 1) as int)));
      first9Scores.add(first9Total);
    }
    
    // Game average for consistency
    final scoresThisGame = throws
        .where((t) => t['wasBust'] == false)
        .map((t) => (t['value'] as int) * (t['multiplier'] as int))
        .toList();
    if (scoresThisGame.isNotEmpty) {
      allGameAverages.add(
        scoresThisGame.reduce((a, b) => a + b) / scoresThisGame.length,
      );
    }
    
    // Round score tracking (group throws by 3)
    for (int i = 0; i < throws.length; i += 3) {
      final roundThrows = throws.skip(i).take(3).toList();
      int roundScore = 0;
      bool isBustRound = false;
      
      for (final t in roundThrows) {
        if (t['wasBust'] == true) {
          isBustRound = true;
          // Continue to calculate score even for bust round
        }
        final value = (t['value'] as int? ?? 0);
        final multiplier = (t['multiplier'] as int? ?? 1);
        roundScore += value * multiplier;
      }
      
      if (isBustRound && roundScore > largestBust) {
        largestBust = roundScore;
      } else if (!isBustRound && roundScore > largestRound) {
        largestRound = roundScore;
      }
    }
  }
  
  // Calculate derived stats
  int hitNum = 0, hitNumCount = 0;
  hitCount.forEach((num, count) {
    if (count > hitNumCount) {
      hitNum = num;
      hitNumCount = count;
    }
  });
  
  String favoriteRoute = '';
  int maxCount = 0;
  checkoutRoutes.forEach((route, count) {
    if (count > maxCount) {
      maxCount = count;
      favoriteRoute = route;
    }
  });
  
  double consistencyRating = 0.0;
  if (allGameAverages.length > 1) {
    final mean = allGameAverages.reduce((a, b) => a + b) / allGameAverages.length;
    final variance = allGameAverages.fold<double>(0.0, (double sum, double score) {
      return sum + ((score - mean) * (score - mean));
    }) / allGameAverages.length;
    final stdDev = variance > 0 ? variance.sqrt() : 0.0;
    final cv = mean > 0 ? stdDev / mean : 0.0;
    consistencyRating = (100 - (cv * 100)).clamp(0.0, 100.0);
  }
  
  return {
    'totalGamesPlayed': totalGames,
    'totalWins': wins,
    'winRate': totalGames > 0 ? (wins / totalGames) * 100 : 0.0,
    'avgScore': allScores.isNotEmpty ? allScores.reduce((a, b) => a + b) / allScores.length : 0.0,
    'bestLegDarts': minDarts == 9999 ? 0 : minDarts,
    'highestCheckout': maxCheckout,
    'mostHitNumber': hitNum,
    'mostHitCount': hitNumCount,
    'hitHeatmap': hitHeatmap,
    'countSingles': singles,
    'countDoubles': doubles,
    'countTriples': triples,
    'countBulls': bulls,
    'checkoutEfficiency': checkoutAttempts > 0 ? (checkoutSuccesses / checkoutAttempts) * 100 : 0.0,
    'favoriteCheckout': favoriteRoute,
    'first9Average': first9Scores.isNotEmpty ? first9Scores.reduce((a, b) => a + b) / first9Scores.length / 9 : 0.0,
    'consistencyRating': consistencyRating,
    'largestRoundScore': largestRound,
    'largestBustScore': largestBust,
  };
}

// Add a helper extension for sqrt since dart:math is not imported in tests
extension on double {
  double sqrt() {
    if (this < 0) return double.nan;
    if (this == 0) return 0;
    
    double guess = this / 2;
    double prevGuess;
    
    do {
      prevGuess = guess;
      guess = (guess + this / guess) / 2;
    } while ((guess - prevGuess).abs() > 0.0001);
    
    return guess;
  }
}
