import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:dars_scoring_app/widgets/spiderweb_painter.dart';

class PlayerInfoScreen extends StatefulWidget {
  final String playerName;
  const PlayerInfoScreen({super.key, required this.playerName});

  @override
  State<PlayerInfoScreen> createState() => _PlayerInfoScreenState();
}

class _PlayerInfoScreenState extends State<PlayerInfoScreen> {
  List<Map<String, dynamic>> lastGames = [];
  double avgScore = 0.0;
  double winRate = 0.0;
  Map<int, int> hitHeatmap = {}; // key: board value, value: hit count
  int totalGamesPlayed = 0;
  int totalWins = 0;
  double highestCheckout = 0;
  int bestLegDarts = 0;
  double avgDartsPerLeg = 0;
  int mostHitNumber = 0;
  int mostHitCount = 0;
  List<bool> recentResults = []; // true = win, false = loss

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
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

    // For winrate, count all games using the winner variable
    for (final g in games.reversed) {
      final game = jsonDecode(g);
      if (!(game['players'] as List).contains(widget.playerName)) continue;
      totalGames++;
      if (game['winner'] == widget.playerName) {
        wins++;
      }
    }

    // For heatmap, avg, and other stats, only last 8 games
    int gamesCounted = 0;
    for (final g in games.reversed) {
      final game = jsonDecode(g);
      if (!(game['players'] as List).contains(widget.playerName)) continue;
      final throws = (game['throws'] as List)
          .where((t) => t['player'] == widget.playerName)
          .toList();

      // Highest checkout
      if (throws.isNotEmpty && throws.last['resultingScore'] == 0) {
        double checkout = ((throws.last['value'] ?? 0) * (throws.last['multiplier'] ?? 1)).toDouble();
        if (checkout > maxCheckout) maxCheckout = checkout;
        // Best leg (fewest darts to finish)
        if (throws.length < minDarts) minDarts = throws.length;
        // Avg darts per leg
        totalDarts += throws.length;
        finishedLegs++;
      }

      // Most hit number
      for (final t in throws) {
        if (t['wasBust'] == true) continue;
        allScores.add((t['value'] ?? 0) * (t['multiplier'] ?? 1));
        int value = t['value'] ?? 0;
        heatmap[value] = (heatmap[value] ?? 0) + 1;
        hitCount[value] = (hitCount[value] ?? 0) + 1;
      }

      // Recent results (win/loss)
      final completed = game['completedAt'] != null;
      final winner = game['winner'];
      if (completed && winner != null) {
        lastResults.add(winner == widget.playerName);
      }

      playerGames.add(game);
      gamesCounted++;
      if (gamesCounted == 8) break;
    }

    // Most hit number
    int hitNum = 0, hitNumCount = 0;
    hitCount.forEach((num, count) {
      if (count > hitNumCount) {
        hitNum = num;
        hitNumCount = count;
      }
    });

    setState(() {
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
    });
  }

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
    final players = (game['players'] as List).cast<String>();
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
    final maxHits = hitHeatmap.values.isEmpty ? 1 : hitHeatmap.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.playerName} Stats')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Overall Average (last 8 games): ${avgScore.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Win Rate: ${winRate.toStringAsFixed(1)}% ($totalWins/$totalGamesPlayed)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Highest Checkout: ${highestCheckout.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Best Leg (Fewest Darts): $bestLegDarts',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Average Darts per Leg: ${avgDartsPerLeg.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Most Hit Number: $mostHitNumber ($mostHitCount times)',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Recent Form: ', style: TextStyle(fontSize: 16)),
                ...recentResults.take(5).map((win) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    win ? Icons.circle : Icons.circle_outlined,
                    color: win ? Colors.green : Colors.red,
                    size: 16,
                  ),
                )),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Dartboard Hit Heatmap:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: hitHeatmap.isEmpty
                  ? const Center(child: Text('No data'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: hitHeatmap.entries
                            .map((e) => BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: e.value.toDouble(),
                                      color: Colors.blue,
                                      width: 8,
                                    ),
                                  ],
                                ))
                            .toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                // Only show whole numbers
                                if (value % 1 == 0) {
                                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                              reservedSize: 24,
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dartboard Spider-Web:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: CustomPaint(
                      painter: SpiderWebPainter(
                        hitHeatmap,
                        maxHits,
                        Theme.of(context).brightness, // pass brightness
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Last 8 Games:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...lastGames.map((g) {
              final date = DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime.now();
              final winner = g['winner'];
              final completed = g['completedAt'] != null;
              final isWin = completed && winner == widget.playerName;
              final isLoss = completed && winner != null && winner != widget.playerName;
              return ListTile(
                title: Text('Game Mode: ${g['gameMode'] ?? ''}'),
                subtitle: Text('Date: ${date.toLocal().toString().split('.')[0]}'),
                trailing: Text(
                  !completed
                      ? 'In Progress'
                      : isWin
                          ? 'Win'
                          : isLoss
                              ? 'Loss'
                              : '',
                  style: TextStyle(
                    color: !completed
                        ? Colors.orange
                        : isWin
                            ? Colors.green
                            : isLoss
                                ? Colors.red
                                : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _showGameDetailsDialog(g),
              );
            }),
          ],
        ),
      ),
    );
  }
}