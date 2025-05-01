import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';

class GameScreen extends StatefulWidget {
  final int startingScore;
  final List<String> players;
  final GameHistory? gameHistory; // <-- Add this

  const GameScreen({
    super.key,
    required this.startingScore,
    required this.players,
    this.gameHistory, // <-- Add this
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<String> players;
  late List<int> scores;
  late String gameId;
  late GameHistory currentGame;
  int currentPlayer = 0;
  int dartsThrown = 0;
  int multiplier = 1;
  int turnStartScore = 0; // <-- Add this
  final List<String> _finishedPlayers = [];

  @override
  void initState() {
    super.initState();

    if (widget.gameHistory != null) {
      // Restore from history
      currentGame = widget.gameHistory!;
      players = List<String>.from(currentGame.players);
      scores = List<int>.filled(players.length, widget.startingScore);

      // Replay throws to restore scores and finished players
      for (final t in currentGame.throws) {
        final idx = players.indexOf(t.player);
        scores[idx] = t.resultingScore;
        if (t.resultingScore == 0 && !_finishedPlayers.contains(t.player)) {
          _finishedPlayers.add(t.player);
        }
      }

      // Set current player and darts thrown
      if (currentGame.throws.isNotEmpty) {
        final lastThrow = currentGame.throws.last;
        currentPlayer = players.indexOf(lastThrow.player);
        // Count how many darts the current player has thrown in this round
        final playerThrows = currentGame.throws.reversed
            .takeWhile((t) => t.player == lastThrow.player)
            .length;
        dartsThrown = playerThrows % 3;
        // Move to next player if needed
        if (dartsThrown == 0) {
          do {
            currentPlayer = (currentPlayer + 1) % players.length;
          } while (_finishedPlayers.contains(players[currentPlayer]) && _finishedPlayers.length < players.length);
        }
      } else {
        currentPlayer = 0;
        dartsThrown = 0;
      }
      gameId = currentGame.id;
    } else {
      // New game
      players = List<String>.from(widget.players);
      players.shuffle(Random());
      scores = List<int>.filled(players.length, widget.startingScore);

      gameId = DateTime.now().millisecondsSinceEpoch.toString();
      currentGame = GameHistory(
        id: gameId,
        players: players,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        throws: [],
        completedAt: null,
        gameMode: widget.startingScore,
      );
      _saveOrUpdateGameHistory();
    }
  }

  Future<void> _saveOrUpdateGameHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> games = prefs.getStringList('games_history') ?? [];
    final idx = games.indexWhere((g) => jsonDecode(g)['id'] == currentGame.id);
    final gameJson = jsonEncode(currentGame.toJson());
    if (idx == -1) {
      games.add(gameJson);
    } else {
      games[idx] = gameJson;
    }
    await prefs.setStringList('games_history', games);
  }

  void _setMultiplier(int value) {
    setState(() {
      // Toggle off if already selected, otherwise set
      multiplier = (multiplier == value) ? 1 : value;
    });
  }

  void _score(int value) async {
    setState(() {
      if (dartsThrown == 0) {
        turnStartScore = scores[currentPlayer]; // <-- Add this
      }

      int hit;
      // 25 and 50 should not benefit from multiplier
      if (value == 25 || value == 50) {
        hit = value;
      } else {
        hit = value * multiplier;
      }
      if (value == 0) hit = 0;

      final int beforeScore = scores[currentPlayer];
      int afterScore = beforeScore - hit;

      bool isDouble = multiplier == 2;
      bool isBull = value == 50;
      bool isBust = false;
      bool isWinningThrow = false;

      // Bust conditions
      if (afterScore < 0 || afterScore == 1) {
        isBust = true;
      } else if (afterScore == 0) {
        // Must finish on double or bull (50)
        if (isDouble || isBull) {
          isWinningThrow = true;
        } else {
          isBust = true;
        }
      }

      if (isBust) {
        // Mark all darts this turn as bust (including this one)
        // Find all throws for this player in this round (max 3, this turn)
        int throwsThisTurn = dartsThrown;
        int throwsFound = 0;
        // Mark already thrown darts as bust
        for (int i = currentGame.throws.length - 1; i >= 0 && throwsFound < throwsThisTurn; i--) {
          if (currentGame.throws[i].player == players[currentPlayer]) {
            currentGame.throws[i] = DartThrow(
              player: currentGame.throws[i].player,
              value: currentGame.throws[i].value,
              multiplier: currentGame.throws[i].multiplier,
              resultingScore: currentGame.throws[i].resultingScore,
              timestamp: currentGame.throws[i].timestamp,
              wasBust: true,
            );
            throwsFound++;
          }
        }
        // Add bust darts for the remaining (not thrown) darts this turn
        for (int i = throwsThisTurn; i < 3; i++) {
          currentGame.throws.add(DartThrow(
            player: players[currentPlayer],
            value: 0,
            multiplier: 1,
            resultingScore: turnStartScore, // <-- Use turnStartScore instead of beforeScore
            timestamp: DateTime.now(),
            wasBust: true,
          ));
        }
        // Reset score to what it was at the start of the turn
        scores[currentPlayer] = turnStartScore; // <-- Use turnStartScore instead of beforeScore
        dartsThrown = 0;
        // Move to next player
        do {
          currentPlayer = (currentPlayer + 1) % players.length;
        } while (_finishedPlayers.contains(players[currentPlayer]) && _finishedPlayers.length < players.length);
      } else {
        // Not a bust, apply the score
        scores[currentPlayer] = afterScore;

        final dartThrow = DartThrow(
          player: players[currentPlayer],
          value: value,
          multiplier: (value == 25 || value == 50) ? 1 : multiplier,
          resultingScore: scores[currentPlayer],
          timestamp: DateTime.now(),
          wasBust: false,
        );
        currentGame.throws.add(dartThrow);

        dartsThrown++;

        // Check if player finished
        if (isWinningThrow && !_finishedPlayers.contains(players[currentPlayer])) {
          _finishedPlayers.add(players[currentPlayer]);
          if (_finishedPlayers.length == players.length) {
            currentGame.completedAt = DateTime.now();
            _saveOrUpdateGameHistory();
          }
          _showWinnerDialog(players[currentPlayer]);
        } else {
          // Next player if 3 darts thrown
          if (dartsThrown >= 3) {
            dartsThrown = 0;
            do {
              currentPlayer = (currentPlayer + 1) % players.length;
            } while (_finishedPlayers.contains(players[currentPlayer]) && _finishedPlayers.length < players.length);
          }
        }
      }

      currentGame.modifiedAt = DateTime.now();
      _saveOrUpdateGameHistory();

      // Reset multiplier after each throw
      multiplier = 1;
    });
  }

  void _showWinnerDialog(String winner) {
    final allFinished = _finishedPlayers.length == players.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Congratulations!'),
        content: Text('$winner has finished!'),
        actions: [
          TextButton(
            onPressed: allFinished
                ? null
                : () {
                    Navigator.of(context).pop();
                    // Continue game for remaining players
                    setState(() {
                      if (_finishedPlayers.length < players.length) {
                        do {
                          currentPlayer = (currentPlayer + 1) % players.length;
                        } while (_finishedPlayers.contains(players[currentPlayer]) && _finishedPlayers.length < players.length);
                        dartsThrown = 0;
                      }
                    });
                  },
            child: const Text('Play on'),
          ),
          ElevatedButton(
            onPressed: () async {
              currentGame.completedAt = DateTime.now();
              await _saveOrUpdateGameHistory();
              if (mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).popUntil((route) => route.isFirst); // Go to home
              }
            },
            child: const Text('End game'),
          ),
        ],
      ),
    );
  }

  void _undoLastThrow() {
    setState(() {
      if (currentGame.throws.isEmpty) return;

      final lastThrow = currentGame.throws.removeLast();
      final playerIdx = players.indexOf(lastThrow.player);

      // Restore the previous score for the player
      int prevScore = widget.startingScore;
      // Find the last throw for this player, if any
      for (final t in currentGame.throws.reversed) {
        if (t.player == lastThrow.player) {
          prevScore = t.resultingScore;
          break;
        }
      }
      scores[playerIdx] = prevScore;

      // Remove from finished players if needed
      if (lastThrow.resultingScore == 0) {
        _finishedPlayers.remove(lastThrow.player);
      }

      // Set current player and darts thrown
      if (currentGame.throws.isNotEmpty) {
        final prev = currentGame.throws.last;
        currentPlayer = players.indexOf(prev.player);
        final playerThrows = currentGame.throws.reversed
            .takeWhile((t) => t.player == prev.player)
            .length;
        dartsThrown = playerThrows % 3;
        if (dartsThrown == 0) {
          do {
            currentPlayer = (currentPlayer + 1) % players.length;
          } while (_finishedPlayers.contains(players[currentPlayer]) && _finishedPlayers.length < players.length);
        }
      } else {
        currentPlayer = 0;
        dartsThrown = 0;
      }

      currentGame.modifiedAt = DateTime.now();
      _saveOrUpdateGameHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.home, color: Colors.grey),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          title: Text('Darts Game (${widget.startingScore})'),
        ),
        body: Column(
          children: [
            // Current player
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  "Current player: ${players[currentPlayer]} (Dart ${dartsThrown + 1}/3)",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // 30% Score
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: Center(
                child: Text(
                  '${scores[currentPlayer]}',
                  style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // 10% Possible finishes
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.1,
              child: Center(
                child: Builder(
                  builder: (context) {
                    final score = scores[currentPlayer];
                    final dartsLeft = 3 - dartsThrown;
                    final finishEntry = possibleFinishes[score];
                    if (finishEntry != null && finishEntry['darts'] <= dartsLeft) {
                      return Text(
                        'Possible finish: ${finishEntry['finish']}',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      );
                    } else {
                      return Text(
                        'No finish possible',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      );
                    }
                  },
                ),
              ),
            ),
            // 60% Dart input
            Expanded(
              flex: 6, // 60% of remaining space
              child: Column(
                children: [
                  // Multiplier buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: multiplier == 2 ? Colors.blue : null,
                        ),
                        onPressed: () => _setMultiplier(2),
                        child: const Text('x2'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: multiplier == 3 ? Colors.blue : null,
                        ),
                        onPressed: () => _setMultiplier(3),
                        child: const Text('x3'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Number buttons grid and special buttons row
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: 22, // 1-20, 25, 50
                            itemBuilder: (context, index) {
                              if (index < 20) {
                                return ElevatedButton(
                                  onPressed: () => _score(index + 1),
                                  child: Text('${index + 1}', style: const TextStyle(fontSize: 16)),
                                );
                              } else if (index == 20) {
                                return ElevatedButton(
                                  onPressed: () => _score(25),
                                  child: const Text('25', style: TextStyle(fontSize: 16)),
                                );
                              } else {
                                return ElevatedButton(
                                  onPressed: () => _score(50),
                                  child: const Text('50', style: TextStyle(fontSize: 16)),
                                );
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 0, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 120, height: 40,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _score(0),
                                  icon: const Icon(Icons.cancel_outlined, size: 20),
                                  label: const Text('Miss', style: TextStyle(fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 120, height: 40,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: _undoLastThrow,
                                  icon: const Icon(Icons.undo, size: 20),
                                  label: const Text('Undo', style: TextStyle(fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}