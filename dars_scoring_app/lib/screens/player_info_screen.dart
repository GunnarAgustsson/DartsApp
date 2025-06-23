import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:dars_scoring_app/widgets/spiderweb_painter.dart';

// import 'package:dars_scoring_app/widgets/spiderweb_painter.dart'; // Removed external spiderweb import

enum HitTypeFilter { all, singles, doubles, triples }
enum DartCountFilter { all, first9, first12 }

class PlayerInfoScreen extends StatefulWidget {
  final String playerName;
  const PlayerInfoScreen({super.key, required this.playerName});

  @override
  State<PlayerInfoScreen> createState() => _PlayerInfoScreenState();
}

class _PlayerInfoScreenState extends State<PlayerInfoScreen> with SingleTickerProviderStateMixin {
  // Add tab controller
  late TabController _tabController;
    // Existing state variables
  List<Map<String, dynamic>> lastGames = [];
  double avgScore = 0.0;
  double winRate = 0.0;
  Map<int, int> hitHeatmap = {};
  int totalGamesPlayed = 0;
  int totalWins = 0;
  double highestCheckout = 0;
  double highestCheckout301 = 0;
  double highestCheckout501 = 0;
  int bestLegDarts = 0;
  double avgDartsPerLeg = 0;
  int mostHitNumber = 0;
  int mostHitCount = 0;
  List<bool> recentResults = [];
  HitTypeFilter _selectedFilter = HitTypeFilter.all;
  DartCountFilter _selectedCountFilter = DartCountFilter.all;
  final ScrollController _heatmapScrollController = ScrollController();
  List<double> _avgPerGameTrend = [];
  int _countSingles = 0, _countDoubles = 0, _countTriples = 0, _countBulls = 0;
  Map<String, int> _finishCount = {};
    // New statistics
  double _first9Average = 0.0;
  double _checkoutEfficiency = 0.0;
  String _favoriteCheckout = "";
  double _consistencyRating = 0.0;
  int _largestRoundScore = 0;
  int _largestBustScore = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _heatmapScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final games = prefs.getStringList('games_history') ?? [];
    final List<Map<String, dynamic>> playerGames = [];
    int wins = 0;
    int totalGames = 0;
    List<int> allScores = [];
    Map<int, int> heatmap = {};
    double maxCheckout = 0;
    int minDarts = 9999; 
    int totalDarts = 0;
    int finishedLegs = 0;
    Map<int, int> hitCount = {};
    List<bool> lastResults = [];
    final List<double> perGameAvgs = [];    final Map<String, int> finishMap = {};
    int singles = 0, doubles = 0, triples = 0, bulls = 0;
    int largestRound = 0;
    int largestBust = 0;

    // For winrate, count only completed games
    for (final g in games.reversed) {
      final game = jsonDecode(g);
      if (!(game['players'] as List).contains(widget.playerName)) continue;
      // skip games still in progress
      if (game['completedAt'] == null) continue;
      totalGames++;
      if (game['winner'] == widget.playerName) {
        wins++;
      }
    }

    // Only completed games for stats and last 8 games
    int gamesCounted = 0;
    for (final g in games.reversed) {
      final game = jsonDecode(g);
      if (!(game['players'] as List).contains(widget.playerName)) continue;
      final completed = game['completedAt'] != null;
      if (!completed) continue; // Only completed games

      final throws = (game['throws'] as List)
          .where((t) => t['player'] == widget.playerName)
          .toList();
        
      // Add this code to calculate best leg
      if (game['winner'] == widget.playerName) {
        // If player won, count their darts for this leg
        final dartsThrown = throws.length;
        if (dartsThrown > 0 && dartsThrown < minDarts) {
          minDarts = dartsThrown;
          print("Found new best leg: $minDarts darts"); // Debug info
        }
      }

      // Improved highest checkout handling
      if (throws.isNotEmpty) {
        final lastThrow = throws.last;
        // Check if the last throw resulted in a checkout
        if (lastThrow['resultingScore'] == 0) {
          // Calculate the checkout value (what was hit)
          final value = lastThrow['value'] ?? 0;
          final multiplier = lastThrow['multiplier'] ?? 1;
          final checkout = (value * multiplier).toDouble();
          
          if (checkout > maxCheckout) {
            maxCheckout = checkout;
            print("Found checkout: $checkout"); // Debug to verify checkouts are found
          }
        }
      }
      
      // Most hit number, heatmap, avg, etc.
      for (final t in throws) {
        if (t['wasBust'] == true) continue;
        allScores.add((t['value'] ?? 0) * (t['multiplier'] ?? 1));
        int value = t['value'] ?? 0;
        heatmap[value] = (heatmap[value] ?? 0) + 1;
        hitCount[value] = (hitCount[value] ?? 0) + 1;
      }

      // Recent results (win/loss)
      final winner = game['winner'];
      if (winner != null) {
        lastResults.add(winner == widget.playerName);
      }

      playerGames.add(game);

      // Compute this game’s average *before* maybe breaking
      final scoresThisGame = throws
          .where((t) => t['wasBust'] == false)
          .map((t) => (t['value'] as int) * (t['multiplier'] as int))
          .toList();
      if (scoresThisGame.isNotEmpty) {
        perGameAvgs.add(
          scoresThisGame.reduce((a, b) => a + b) / scoresThisGame.length,
        );
      }

      gamesCounted++;
      if (gamesCounted == 8) break; // Only last 8 completed games      // Count segment‐type distribution
      for (final t in throws) {
        if (t['wasBust'] == true) continue;
        final v = t['value'] as int;
        final m = t['multiplier'] as int;
        if (v == 25 || v == 50) {
          bulls++;
        } else if (m == 3) {
          triples++;
        } else if (m == 2) {
          doubles++;
        } else {
          singles++;
        }
      }

      // Track largest round score and largest bust
      // Group throws by consecutive turns (3 darts each)
      for (int i = 0; i < throws.length; i += 3) {
        final roundThrows = throws.skip(i).take(3).toList();
        int roundScore = 0;
        bool isBustRound = false;
        
        for (final t in roundThrows) {
          if (t['wasBust'] == true) {
            isBustRound = true;
            break;
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

      // Record finish segment
      if (throws.isNotEmpty && throws.last['resultingScore'] == 0) {
        final t = throws.last;
        final v = t['value'] as int;
        final m = t['multiplier'] as int;
        String code;
        if (v == 50) {
          code = 'DB';
        } else if (v == 25) code = 'SB';
        else if (m == 3) code = 'T$v';
        else if (m == 2) code = 'D$v';
        else code = 'S$v';
        finishMap[code] = (finishMap[code] ?? 0) + 1;
      }
    }

    // Most hit number
    int hitNum = 0, hitNumCount = 0;
    hitCount.forEach((num, count) {
      if (count > hitNumCount) {
        hitNum = num;
        hitNumCount = count;
      }
    });

    // DIRECT calculation of checkout stats - no callbacks
    int checkoutAttempts = 0;
    int checkoutSuccesses = 0;
    
    for (final g in games.reversed) {
      final game = jsonDecode(g);
      if (!(game['players'] as List).contains(widget.playerName)) continue;
      if (game['completedAt'] == null) continue; // Skip incomplete games
      
      final throws = (game['throws'] as List)
          .where((t) => t['player'] == widget.playerName)
          .toList();
      
      // Track checkout attempts and successes directly
      for (int i = 0; i < throws.length; i++) {
        final t = throws[i];
        final score = t['resultingScore'] as int;
        final prevScore = i > 0 ? throws[i-1]['resultingScore'] as int : game['gameMode'] as int;
        
        // If previous score was in checkout range (≤ 170)
        if (prevScore <= 170 && prevScore > 0) {
          checkoutAttempts++;
          
          // If this throw resulted in a win
          if (score == 0) {
            checkoutSuccesses++;
            
            // Calculate the checkout value
            final value = t['value'] as int;
            final multiplier = t['multiplier'] as int;
            final checkout = value * multiplier;
            
            // Update highest checkout
            if (checkout > maxCheckout) {
              maxCheckout = checkout.toDouble();
              print("Found checkout: $checkout"); // Debug
            }
          }
        }
      }
    }
    
    // Now call _calculateAdvancedStats to get other statistics
    _calculateAdvancedStats(games);    setState(() {
      lastGames = playerGames;
      avgScore = allScores.isNotEmpty
          ? allScores.reduce((a, b) => a + b) / allScores.length
          : 0.0;
      winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;
      hitHeatmap = heatmap;
      totalGamesPlayed = totalGames;
      totalWins = wins;
      highestCheckout = maxCheckout;
      bestLegDarts = minDarts == 9999 ? 0 : minDarts;
      avgDartsPerLeg = finishedLegs > 0 ? totalDarts / finishedLegs : 0.0;
      mostHitNumber = hitNum;
      mostHitCount = hitNumCount;
      recentResults = lastResults;
      _avgPerGameTrend = perGameAvgs.reversed.toList();
      _countSingles = singles;
      _countDoubles = doubles;
      _countTriples = triples;
      _countBulls = bulls;      _finishCount = finishMap;
      _isLoading = false;
      _checkoutEfficiency = checkoutAttempts > 0 ? (checkoutSuccesses / checkoutAttempts) * 100 : 0.0;
      _largestRoundScore = largestRound;
      _largestBustScore = largestBust;
    });
  }

  // Make sure you call this after you’ve built finishMap / hits, so you get a real favorite:
  void _calculateAdvancedStats(List<String> games) {
    // Calculate First 9 Average
    List<int> first9Scores = [];
    
    // DON'T track checkout attempts and successes here anymore
    // (we're doing this directly in _loadStats)
    
    // Favorite checkout tracking still useful
    Map<String, int> checkoutRoutes = {};
    
    // Consistency tracking (variance in scores)
    List<double> allGameAverages = [];
    
    // Day of week tracking
    Map<String, int> winsByDay = {'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0};
    Map<String, int> gamesByDay = {'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0};
    
    for (final g in games.reversed) {
      final game = jsonDecode(g);
      if (!(game['players'] as List).contains(widget.playerName)) continue;
      final completed = game['completedAt'] != null;
      if (!completed) continue;
      
      final throws = (game['throws'] as List)
          .where((t) => t['player'] == widget.playerName)
          .toList();
      
      // First 9 darts average
      final first9 = throws.take(9).toList();
      if (first9.isNotEmpty) {
        final first9Total = first9.fold<int>(0, (sum, t) => 
          sum + (t['wasBust'] == true ? 0 : ((t['value'] ?? 0) as int) * ((t['multiplier'] ?? 0) as int)));
        first9Scores.add(first9Total);
      }
      
      // Checkout routes tracking
      if (throws.isNotEmpty) {
        final lastThrow = throws.last;
        // The key issue - resultingScore needs to be explicitly cast to int for comparison
        final resultingScore = lastThrow['resultingScore'] as int?;
        
        // Add debug logging
        print("Player: ${widget.playerName}, Last throw score: $resultingScore");
        
        if (resultingScore == 0) {
          print("FOUND A CHECKOUT!");
          // Record checkout route (ONLY the last dart)
          final v = lastThrow['value'] as int? ?? 0;
          final m = lastThrow['multiplier'] as int? ?? 1;
          String route; // This will be the single segment code of the last dart

          if (v == 50) {
            route = 'DB';
          } else if (v == 25 && m == 1) { // Ensure SB is m == 1
            route = 'SB';
          } else if (m == 3) {
            route = 'T$v';
          } else if (m == 2) {
            route = 'D$v';
          } else {
            route = 'S$v'; // Single (non-bull)
          }
          
          // For debugging
          print("Recording checkout route (single dart): $route");
          checkoutRoutes[route] = (checkoutRoutes[route] ?? 0) + 1;
        }
      }
      
      // Game average for consistency calculation
      final scoresThisGame = throws
          .where((t) => t['wasBust'] == false)
          .map((t) => (t['value'] as int) * (t['multiplier'] as int))
          .toList();
          
      if (scoresThisGame.isNotEmpty) {
        allGameAverages.add(
          scoresThisGame.reduce((a, b) => a + b) / scoresThisGame.length,
        );
      }
      
      // Day of week stats
      final gameDate = DateTime.tryParse(game['createdAt'] ?? '') ?? DateTime.now();
      final dayName = DateFormat('E').format(gameDate); // 'Mon', 'Tue', etc.
      gamesByDay[dayName] = (gamesByDay[dayName] ?? 0) + 1;
      
      if (game['winner'] == widget.playerName) {
        winsByDay[dayName] = (winsByDay[dayName] ?? 0) + 1;
      }
    }
    
    // Calculate First 9 Average
    _first9Average = first9Scores.isNotEmpty 
        ? first9Scores.reduce((a, b) => a + b) / first9Scores.length / 9
        : 0.0;
    
    // Favorite Checkout
    String favoriteRoute = "";
    int maxCount = 0;
    checkoutRoutes.forEach((route, count) {
      if (count > maxCount) {
        maxCount = count;
        favoriteRoute = route;
      }
    });    _favoriteCheckout        = favoriteRoute;
    
    // Consistency Rating (inverse of coefficient of variation, scaled to 0-100)
    if (allGameAverages.length > 1) {
      final mean = allGameAverages.reduce((a, b) => a + b) / allGameAverages.length;
      final variance = allGameAverages.fold<double>(0.0, (double sum, double score) {
        return sum + math.pow(score - mean, 2).toDouble();
      }) / allGameAverages.length;
      final stdDev = math.sqrt(variance);
      final cv = stdDev / mean; // Coefficient of variation
      _consistencyRating = math.max(0, math.min(100, 100 - (cv * 100)));
    } else {
      _consistencyRating = 0.0;
    }
    
    // Improvement Rate (linear regression of game averages)
    if (allGameAverages.length > 3) {      // Simple linear regression
      // final n = allGameAverages.length;
      // final indices = List.generate(n, (i) => i.toDouble());
      
      // Note: For trend analysis, variables would be used for slope calculation
      // final sumX = indices.reduce((a, b) => a + b);
      // final sumY = allGameAverages.reduce((a, b) => a + b);
      // final sumXY = indices.asMap().entries.fold<double>(
      //   0.0,
      //   (double sum, MapEntry<int, double> entry) =>
      //     sum + entry.value * allGameAverages[entry.key],
      // );
      // final sumX2 = indices.fold<double>(0.0, (double sum, double x) => sum + x * x);
      // avoid division by zero
      // final denom = (n * sumX2 - sumX * sumX);
      
      // Remove calculation as improvement rate is not displayed
    } else {
      // Remove assignment to undefined variable
    }    // Best Day To Play (removed unused variable assignment)
    double bestWinRate = 0.0;
    
    gamesByDay.forEach((day, games) {
      if (games > 0) {
        final wins = winsByDay[day] ?? 0;
        final rate = (wins / games) * 100;
        if (rate > bestWinRate) {
          bestWinRate = rate;
          // Remove assignment to unused variable
        }
      }
    });
    // Removed assignment to undefined variable
  }

  Map<int, int> _filteredHeatmap(HitTypeFilter hitTypeFilter) {
    final filtered = <int, int>{};
    // Initialize all possible values to zero
    for (final entry in hitHeatmap.entries) {
      filtered[entry.key] = 0;
    }

    // Process completed games only
    for (final g in lastGames.where((g) => g['completedAt'] != null)) {
      // Get all throws for this player in this game
      var throwsList = (g['throws'] as List)
          .where((t) => t['player'] == widget.playerName)
          .toList();
    
      // Apply dart count filter FIRST - this is crucial
      // The count filter should be applied to the entire throw set
      switch (_selectedCountFilter) {        case DartCountFilter.first9:
          throwsList = throwsList.take(9).toList();
          break;
        case DartCountFilter.first12:
          throwsList = throwsList.take(12).toList();
          break;
        case DartCountFilter.all:
          break;
      }
      // THEN apply hit type filter
      for (final t in throwsList) {
        if (t['wasBust'] == true) continue;
      
        final v = t['value'] as int? ?? 0;
        final m = t['multiplier'] as int? ?? 1;
      
        // Skip bullseye (25 and 50) from hit pattern analysis
        if (v == 25 || v == 50) continue;
      
        // Special handling for other segments
        bool shouldCount = false;
      
        if (hitTypeFilter == HitTypeFilter.all) {
          shouldCount = true;
        } else if (hitTypeFilter == HitTypeFilter.singles) {
          shouldCount = (m == 1); // Regular singles (bullseye already excluded above)
        } else if (hitTypeFilter == HitTypeFilter.doubles) {
          shouldCount = (m == 2); // Doubles (bullseye excluded)
        } else if (hitTypeFilter == HitTypeFilter.triples) {
          shouldCount = (m == 3); // Triples
        }
      
        if (shouldCount) {
          filtered[v] = (filtered[v] ?? 0) + 1;
        }
      }
    }
    
    return filtered;  }

  void _showGameDetailsDialog(Map<String, dynamic> game) {
    final throws = (game['throws'] as List)
        .map((t) => {
              'player': t['player'],
              'value': t['value'],
              'multiplier': t['multiplier'],
              'resultingScore': t['resultingScore'],
              'wasBust': t['wasBust'] ?? false,
            })
        .toList();
    final date = DateTime.tryParse(game['createdAt'] ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Game Details (${date.toLocal().toString().split('.')[0]})'),
          content: SizedBox(
            width: double.maxFinite,
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: throws.length,
                itemBuilder: (context, index) {
                  final t = throws[index];
                  return ListTile(
                    dense: true,
                    title: Text('${t['player']}'),
                    subtitle: t['wasBust'] == true
                        ? Text(
                            'Hit: ${t['value']} x${t['multiplier']} | Score after: ${t['resultingScore']}  (Bust)',
                            style: const TextStyle(color: Colors.red),
                          )
                        : Text(
                            'Hit: ${t['value']} x${t['multiplier']} | Score after: ${t['resultingScore']}',
                          ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.playerName} Stats')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.playerName} Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh Stats',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.insights), text: 'Trends'),
            Tab(icon: Icon(Icons.sports), text: 'Hitting'),
            Tab(icon: Icon(Icons.casino), text: 'Cricket'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,        children: [
          _buildOverviewTab(),
          _buildTrendsTab(),
          _buildHittingTab(),
          _buildCricketTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildKeyStatsCards(),
          const SizedBox(height: 16),
          // Keep just the segment distribution card
          _buildSegmentDistributionCard(),
        ],
      ),
    );
  }

  // Add this method to extract just the segment distribution part
  Widget _buildSegmentDistributionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Segment Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: _countSingles.toDouble(),
                          color: Colors.blue,
                          title: 'Singles',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: _countDoubles.toDouble(),
                          color: Colors.green,
                          title: 'Doubles',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: _countTriples.toDouble(),
                          color: Colors.red,
                          title: 'Triples',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: _countBulls.toDouble(),
                          color: Colors.orange,
                          title: 'Bulls',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                      ],
                      centerSpaceRadius: 0,
                      sectionsSpace: 2,
                    )),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Singles', Colors.blue, _countSingles),
                      const SizedBox(height: 8),
                      _buildLegendItem('Doubles', Colors.green, _countDoubles),
                      const SizedBox(height: 8),
                      _buildLegendItem('Triples', Colors.red, _countTriples),
                      const SizedBox(height: 8),
                      _buildLegendItem('Bulls', Colors.orange, _countBulls),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildHeaderCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade600,
              Colors.blue.shade800,
              Colors.indigo.shade900,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Player info header
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.playerName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playerName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalGamesPlayed games played',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalWins wins (${winRate.toStringAsFixed(1)}%)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Main statistics row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _enhancedStatItem('Avg', avgScore.toStringAsFixed(1), Icons.trending_up, Colors.white),
                  _enhancedDivider(),
                  _enhancedStatItem(
                    'High Checkout', 
                    '${highestCheckout.toInt()}', 
                    Icons.star,
                    Colors.amber
                  ),
                  _enhancedDivider(),
                  _enhancedStatItem(
                    'Favorite', 
                    _favoriteCheckout.isEmpty ? 'N/A' : _favoriteCheckout, 
                    Icons.favorite,
                    Colors.lightGreenAccent
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Secondary statistics row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _enhancedStatItem('Best Leg', '$bestLegDarts darts', Icons.speed, Colors.greenAccent),
                  _enhancedDivider(),
                  _enhancedStatItem('Largest Round', '$_largestRoundScore', Icons.whatshot, Colors.deepOrange),
                  _enhancedDivider(),
                  _enhancedStatItem('Largest Bust', '$_largestBustScore', Icons.error_outline, Colors.redAccent),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Recent form indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Recent Form: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...recentResults.take(5).map((win) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: win ? Colors.green.shade400 : Colors.red.shade400,
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: (win ? Colors.green : Colors.red).withOpacity(0.3),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );  }

  Widget _enhancedStatItem(String label, String value, IconData icon, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: valueColor, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _enhancedDivider() {
    return Container(
      width: 1,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'Key Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Average Score',
                avgScore.toStringAsFixed(1),
                Icons.equalizer,
                Colors.blue,
                'Average score per dart thrown',
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'First 9 Avg',
                _first9Average.toStringAsFixed(1),
                Icons.speed,
                Colors.orange,
                'Average score in first 9 darts',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Checkout %',
                '${_checkoutEfficiency.toStringAsFixed(1)}%',
                Icons.check_circle_outline,
                Colors.green,
                'Percentage of successful checkouts',
              ),
            ),
            Expanded(
              child: _buildStatCard(
                'Consistency',
                '${_consistencyRating.toStringAsFixed(0)}/100',
                Icons.balance,
                Colors.purple,
                'Rating of how consistent your scoring is',
              ),
            ),
          ],
        ),
      ],
    );
  }

  

  Widget _buildLegendItem(String label, Color color, int count) {
    final total = _countSingles + _countDoubles + _countTriples + _countBulls;
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
    
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $count ($percentage%)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  Widget _buildStatCard(String title, String value, IconData icon, Color color, String tooltip) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.05),
              color.withOpacity(0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Tooltip(
                    message: tooltip,
                    child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    final spots = _avgPerGameTrend.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value)).toList();
        
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Average Score Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your average score per dart in recent games',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: spots.isEmpty 
                      ? const Center(child: Text('Not enough data')) 
                      : LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (spots) {
                                return spots.map((spot) {
                                  return LineTooltipItem(
                                    spot.y.toStringAsFixed(1),
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              }
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 1, // Suggest to the chart to consider titles at each integer interval
                                getTitlesWidget: (value, meta) {
                                  // Check if this 'value' (x-coordinate) corresponds to an actual data point
                                  final isDataPointX = spots.any((spot) => spot.x == value);

                                  if (isDataPointX) {
                                    // Ensure the value is a valid index for the spots
                                    // spots are 0-indexed, so game number is value + 1
                                    if (value >= 0 && value < spots.length) {
                                      return SideTitleWidget(
                                        meta: meta,
                                        space: 8,
                                        child: Text(
                                          '${value.toInt() + 1}', // Display 1-indexed game number
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }
                                  }
                                  // For any other case, or if value is not an x-coordinate of a spot, return an empty widget
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 8,
                                    child: Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300),
                              left: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blue.withOpacity(0.1),
                              ),
                            ),
                          ],
                          minY: spots.isEmpty ? 0 : (spots.map((s) => s.y).reduce(math.min) * 0.8),
                          maxY: spots.isEmpty ? 60 : (spots.map((s) => s.y).reduce(math.max) * 1.2),
                        ),
                      ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProgressIndicator('Consistency', _consistencyRating / 100, Colors.purple),
                  const SizedBox(height: 16),
                  _buildProgressIndicator('Checkout Efficiency', _checkoutEfficiency / 100, Colors.green),
                  const SizedBox(height: 16),
                  _buildProgressIndicator(
                    'Win Rate', 
                    winRate / 100, 
                    Colors.orange
                  ),
                ],
              ),
            ),
          ),
          if (_finishCount.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Favorite Checkout Segments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...(_finishCount.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                      .take(5)
                      .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getSegmentColor(e.key),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getSegmentName(e.key),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${e.value} times',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                widthFactor: e.value / _finishCount.values.reduce(math.max),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getSegmentColor(e.key),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getSegmentColor(String segment) {
    if (segment.startsWith('T')) return Colors.red;
    if (segment.startsWith('D')) return Colors.green;
    if (segment == 'DB') return Colors.red;
    if (segment == 'SB') return Colors.green;
    return Colors.blue;
  }

  String _getSegmentName(String segment) {
    if (segment == 'DB') return 'Double Bull (50)';
    if (segment == 'SB') return 'Single Bull (25)';
    if (segment.startsWith('T')) return 'Triple ${segment.substring(1)}';
    if (segment.startsWith('D')) return 'Double ${segment.substring(1)}';
    if (segment.startsWith('S')) return 'Single ${segment.substring(1)}';
    return segment;
  }

  Widget _buildProgressIndicator(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHittingTab() {
    // Ensure _filteredHeatmap and maxHits calculation are correct
    final filteredHeatmap = _filteredHeatmap(_selectedFilter);
    final maxHits = filteredHeatmap.values.isEmpty ? 1 : filteredHeatmap.values.reduce(math.max); // Use math.max

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hit Pattern Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All Hits'),
                        selected: _selectedFilter == HitTypeFilter.all,
                        onSelected: (_) => setState(() => _selectedFilter = HitTypeFilter.all),
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade800,
                      ),
                      FilterChip(
                        label: const Text('Singles'),
                        selected: _selectedFilter == HitTypeFilter.singles,
                        onSelected: (_) => setState(() => _selectedFilter = HitTypeFilter.singles),
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade800,
                      ),
                      FilterChip(
                        label: const Text('Doubles'),
                        selected: _selectedFilter == HitTypeFilter.doubles,
                        onSelected: (_) => setState(() => _selectedFilter = HitTypeFilter.doubles),
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade800,
                      ),
                      FilterChip(
                        label: const Text('Triples'),
                        selected: _selectedFilter == HitTypeFilter.triples,
                        onSelected: (_) => setState(() => _selectedFilter = HitTypeFilter.triples),
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All Darts'),
                        selected: _selectedCountFilter == DartCountFilter.all,
                        onSelected: (_) => setState(() => _selectedCountFilter = DartCountFilter.all),
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade800,
                      ),
                      FilterChip(
                        label: const Text('First 9'),
                        selected: _selectedCountFilter == DartCountFilter.first9,
                        onSelected: (_) => setState(() => _selectedCountFilter = DartCountFilter.first9),
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade800,
                      ),
                      FilterChip(
                        label: const Text('First 12'),
                        selected: _selectedCountFilter == DartCountFilter.first12,
                        onSelected: (_) => setState(() => _selectedCountFilter = DartCountFilter.first12),
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: 1.0, // Keep it square
                    child: CustomPaint( // No extra container or padding needed here
                      painter: SpiderWebPainter(
                        filteredHeatmap,
                        maxHits,
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Segment Hit Frequency',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: filteredHeatmap.isEmpty
                      ? const Center(child: Text('No data available'))
                      : Scrollbar(
                          thumbVisibility: true,
                          controller: _heatmapScrollController,
                          child: SingleChildScrollView(
                            controller: _heatmapScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: filteredHeatmap.length * 50.0,
                              child: Builder(
                                builder: (context) {
                                  final sortedEntries = filteredHeatmap.entries.toList()
                                    ..sort((a, b) => b.value.compareTo(a.value));
                                  return BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      barGroups: sortedEntries
                                          .asMap()
                                          .entries
                                          .map((entry) => BarChartGroupData(
                                                x: entry.key,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: entry.value.value.toDouble(),
                                                    color: entry.value.key == 0 
                                                        ? Colors.red 
                                                        : entry.value.key == 25 || entry.value.key == 50
                                                            ? Colors.green
                                                            : Colors.blue.shade700,
                                                    width: 25,
                                                    borderRadius: const BorderRadius.only(
                                                      topLeft: Radius.circular(4),
                                                      topRight: Radius.circular(4),
                                                    ),
                                                    backDrawRodData: BackgroundBarChartRodData(
                                                      show: true,
                                                      toY: maxHits.toDouble(),
                                                      color: Colors.grey.shade200,
                                                    ),
                                                  ),
                                                ],
                                              ))
                                          .toList(),
                                      titlesData: FlTitlesData(
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              final idx = value.toInt();
                                              if (idx >= 0 && idx < sortedEntries.length) {
                                                return SideTitleWidget(
                                                  meta: meta,
                                                  space: 4,
                                                  child: Text(
                                                    sortedEntries[idx].key == 0 
                                                        ? 'Miss' 
                                                        : sortedEntries[idx].key == 25
                                                            ? 'SB'
                                                            : sortedEntries[idx].key == 50
                                                                ? 'DB'
                                                                : sortedEntries[idx].key.toString(),
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                            reservedSize: 24,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      gridData: FlGridData(
                                        show: true,
                                        getDrawingHorizontalLine: (value) => FlLine(
                                          color: Colors.grey.shade200,
                                          strokeWidth: 1,
                                        ),
                                        drawVerticalLine: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCricketTab() {
    // Load Cricket game stats
    final cricketGames = lastGames.where((g) => g['gameMode'] == 'Cricket').toList();
    
    if (cricketGames.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.casino, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Cricket Games Played',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Start playing Cricket to see statistics here!',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Calculate Cricket statistics
    int totalCricketGames = cricketGames.length;
    int cricketWins = cricketGames.where((g) => g['winner'] == widget.playerName).length;
    double cricketWinRate = totalCricketGames > 0 ? (cricketWins / totalCricketGames) * 100 : 0.0;
    
    // Count hits on each cricket number
    Map<int, int> cricketHits = {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0};
    Map<int, int> cricketCloses = {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0};
    int totalCricketScore = 0;
    double avgCricketScore = 0.0;
    
    for (final game in cricketGames) {
      final throws = (game['throws'] as List)
          .where((t) => t['player'] == widget.playerName)
          .toList();
      
      // Track hits per number
      Map<int, int> gameHits = {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0};
      int gameScore = 0;
      
      for (final dartThrow in throws) {
        final value = dartThrow['value'] as int;
        final multiplier = dartThrow['multiplier'] as int;
        
        if (cricketHits.containsKey(value)) {
          cricketHits[value] = cricketHits[value]! + multiplier;
          gameHits[value] = gameHits[value]! + multiplier;
        }
      }
      
      // Count closes (numbers with 3+ hits)
      gameHits.forEach((number, hits) {
        if (hits >= 3) {
          cricketCloses[number] = cricketCloses[number]! + 1;
        }
      });
      
      // Get final score from playerStates if available
      if (game['playerStates'] != null && game['playerStates'][widget.playerName] != null) {
        gameScore = game['playerStates'][widget.playerName]['score'] ?? 0;
      }
      totalCricketScore += gameScore;
    }
    
    avgCricketScore = totalCricketGames > 0 ? totalCricketScore / totalCricketGames : 0.0;
    
    // Find favorite number (most hits)
    int favoriteNumber = 20;
    int maxHits = 0;
    cricketHits.forEach((number, hits) {
      if (hits > maxHits) {
        maxHits = hits;
        favoriteNumber = number;
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cricket Overview Stats
          _buildStatsCard(
            title: 'Cricket Overview',
            children: [
              _buildStatRow('Games Played', totalCricketGames.toString()),
              _buildStatRow('Games Won', cricketWins.toString()),
              _buildStatRow('Win Rate', '${cricketWinRate.toStringAsFixed(1)}%'),
              _buildStatRow('Avg Score', avgCricketScore.toStringAsFixed(1)),
              _buildStatRow(
                'Favorite Number', 
                favoriteNumber == 25 ? 'Bull ($maxHits hits)' : '$favoriteNumber ($maxHits hits)'
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Cricket Numbers Performance
          _buildStatsCard(
            title: 'Numbers Performance',
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('Number', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Total Hits', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Games Closed', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Close Rate', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    // Data rows
                    ...cricketHits.entries.map((entry) {
                      final number = entry.key;
                      final hits = entry.value;
                      final closes = cricketCloses[number]!;
                      final closeRate = totalCricketGames > 0 ? (closes / totalCricketGames) * 100 : 0.0;
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2, 
                              child: Text(
                                number == 25 ? 'Bull' : number.toString(),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 2, 
                              child: Text(
                                hits.toString(), 
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2, 
                              child: Text(
                                '$closes/$totalCricketGames', 
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2, 
                              child: Text(
                                '${closeRate.toStringAsFixed(0)}%', 
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: closeRate >= 75 ? Colors.green : 
                                         closeRate >= 50 ? Colors.orange : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Recent Cricket Games
          _buildStatsCard(
            title: 'Recent Cricket Games',
            children: [
              ...cricketGames.take(5).map((game) {
                final date = DateTime.parse(game['createdAt']);
                final completed = game['completedAt'] != null;
                final isWin = game['winner'] == widget.playerName;
                final winner = game['winner'];
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      'Cricket Game',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM d, yyyy - h:mm a').format(date.toLocal()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          !completed
                              ? 'In Progress'
                              : isWin
                                  ? 'You won!'
                                  : 'Winner: $winner',
                          style: TextStyle(
                            color: !completed
                                ? Colors.orange
                                : isWin
                                    ? Colors.green
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(
                      completed 
                          ? (isWin ? Icons.emoji_events : Icons.sports) 
                          : Icons.play_circle_outline,
                      color: completed 
                          ? (isWin ? Colors.amber : Colors.grey) 
                          : Colors.blue,
                    ),
                    isThreeLine: true,
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method for building stats cards
  Widget _buildStatsCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  // Helper method for building stat rows
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Build history tab (simple implementation for now)
  Widget _buildHistoryTab() {
    final completedGames = lastGames.where((g) => g['completedAt'] != null).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game History',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (completedGames.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No completed games yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ...completedGames.take(20).map((g) {
              final date = DateTime.parse(g['createdAt']);
              final completed = g['completedAt'] != null;
              final isWin = g['winner'] == widget.playerName;
              final winner = g['winner'];
              final gameMode = g['gameMode'];
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    gameMode == 'Cricket' ? 'Cricket Game' : 'Game Mode: $gameMode',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy - h:mm a').format(date.toLocal()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !completed
                            ? 'In Progress'
                            : isWin
                                ? 'You won!'
                                : 'Winner: $winner',
                        style: TextStyle(
                          color: !completed
                              ? Colors.orange
                              : isWin
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showGameDetailsDialog(g),
                    tooltip: 'Game Details',
                  ),
                  isThreeLine: true,
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}

// Custom widget needed for the circle segments
class SegmentedCircle extends StatelessWidget {
  final Map<String, double> segments;
  final double radius;
  final Map<String, Color> colors;
  
  const SegmentedCircle({
    super.key,
    required this.segments,
    required this.radius,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CustomPaint(
        painter: SegmentedCirclePainter(
          segments: segments,
          colors: colors,
        ),
      ),
    );
  }
}

class SegmentedCirclePainter extends CustomPainter {
  final Map<String, double> segments;
  final Map<String, Color> colors;
  
  SegmentedCirclePainter({
    required this.segments,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2;

    double startAngle = -math.pi/2;
    final total = segments.values.fold<double>(0,(s,v)=>s+v);

    for (final e in segments.entries) {
      final sweep = 2*math.pi*(e.value/total);
      final paint = Paint()..color = colors[e.key] ?? Colors.grey;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
                     startAngle, sweep, true, paint);

      // label
      final labelAngle = startAngle + sweep/2;
      final labelPos = Offset(
        center.dx + math.cos(labelAngle)*radius*0.7,
        center.dy + math.sin(labelAngle)*radius*0.7,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: e.key,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        )
      )..layout();
      tp.paint(canvas, labelPos - Offset(tp.width/2, tp.height/2));

      startAngle += sweep;
    }
  }

  @override bool shouldRepaint(covariant CustomPainter old) => true;
}