import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GameScreen extends StatefulWidget {
  final int startingScore;
  final List<String> players;
  final GameHistory? gameHistory;

  const GameScreen({
    super.key,
    required this.startingScore,
    required this.players,
    this.gameHistory,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<String> players;
  late List<int> scores;
  late String gameId;
  late GameHistory currentGame;
  int currentPlayer = 0;
  int dartsThrown = 0;
  int multiplier = 1;
  int turnStartScore = 0;
  final List<String> _finishedPlayers = [];
  bool showBust = false;
  bool showTurnChange = false;
  late AnimationController _bustController;
  late Animation<Color?> _bustColorAnimation;
  late AnimationController _turnController;
  late Animation<Color?> _turnColorAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.gameHistory != null) {
      currentGame = widget.gameHistory!;
      players = List<String>.from(currentGame.players);
      scores = List<int>.filled(players.length, widget.startingScore);

      for (final t in currentGame.throws) {
        final idx = players.indexOf(t.player);
        scores[idx] = t.resultingScore;
        if (t.resultingScore == 0 && !_finishedPlayers.contains(t.player)) {
          _finishedPlayers.add(t.player);
        }
      }

      if (currentGame.throws.isNotEmpty) {
        final lastThrow = currentGame.throws.last;
        currentPlayer = players.indexOf(lastThrow.player);
        final playerThrows = currentGame.throws.reversed
            .takeWhile((t) => t.player == lastThrow.player)
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
      gameId = currentGame.id;
    } else {
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

    _bustController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bustColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red.withOpacity(0.7),
    ).animate(_bustController);

    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _turnColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.blue.withOpacity(0.7),
    ).animate(_turnController);
  }

  @override
  void dispose() {
    _bustController.dispose();
    _turnController.dispose();
    super.dispose();
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
      multiplier = (multiplier == value) ? 1 : value;
    });
  }

  void _score(int value) async {
    setState(() {
      if (dartsThrown == 0) {
        turnStartScore = scores[currentPlayer];
      }

      int hit;
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

      if (afterScore < 0 || afterScore == 1) {
        isBust = true;
      } else if (afterScore == 0) {
        if (isDouble || isBull) {
          isWinningThrow = true;
        } else {
          isBust = true;
        }
      }

      if (isBust) {
        int throwsThisTurn = dartsThrown;
        int throwsFound = 0;
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
        for (int i = throwsThisTurn; i < 3; i++) {
          currentGame.throws.add(DartThrow(
            player: players[currentPlayer],
            value: 0,
            multiplier: 1,
            resultingScore: turnStartScore,
            timestamp: DateTime.now(),
            wasBust: true,
          ));
        }
        scores[currentPlayer] = turnStartScore;
        dartsThrown = 0;

        showBust = true;
        _bustController.forward(from: 0);
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            showBust = false;
            _bustController.reset();
            showTurnChange = true;
            _turnController.forward(from: 0);
            Future.delayed(const Duration(seconds: 2), () {
              setState(() {
                showTurnChange = false;
                _turnController.reset();
              });
            });
            do {
              currentPlayer = (currentPlayer + 1) % players.length;
            } while (_finishedPlayers.contains(players[currentPlayer]) && _finishedPlayers.length < players.length);
          });
        });
      } else {
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

        if (isWinningThrow && !_finishedPlayers.contains(players[currentPlayer])) {
          _finishedPlayers.add(players[currentPlayer]);
          if (_finishedPlayers.length == players.length) {
            currentGame.completedAt = DateTime.now();
            _saveOrUpdateGameHistory();
          }
          _showWinnerDialog(players[currentPlayer]);
        } else {
          if (dartsThrown >= 3) {
            dartsThrown = 0;
            showTurnChange = true;
            _turnController.forward(from: 0);
            Future.delayed(const Duration(seconds: 2), () {
              setState(() {
                showTurnChange = false;
                _turnController.reset();
                do {
                  currentPlayer = (currentPlayer + 1) % players.length;
                } while (_finishedPlayers.contains(players[currentPlayer]) && _finishedPlayers.length < players.length);
              });
            });
          }
        }
      }

      currentGame.modifiedAt = DateTime.now();
      _saveOrUpdateGameHistory();
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
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
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

      int prevScore = widget.startingScore;
      for (final t in currentGame.throws.reversed) {
        if (t.player == lastThrow.player) {
          prevScore = t.resultingScore;
          break;
        }
      }
      scores[playerIdx] = prevScore;

      if (lastThrow.resultingScore == 0) {
        _finishedPlayers.remove(lastThrow.player);
      }

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
          backgroundColor: Colors.grey[200], // Light-grey background
          leading: IconButton(
            icon: const Icon(Icons.home, color: Colors.grey),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          title: Text(
            'Darts Game (${widget.startingScore})',
            style: const TextStyle(color: Colors.black), // Make title text dark for contrast
          ),
          iconTheme: const IconThemeData(color: Colors.grey), // Make icons grey
        ),
        body: Column(
          children: [
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  "${players[currentPlayer]}",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.20,
              child: AnimatedBuilder(
                animation: Listenable.merge([_bustController, _turnController]),
                builder: (context, child) {
                  Color? bgColor = Colors.transparent;
                  if (showBust) {
                    bgColor = _bustColorAnimation.value;
                  } else if (showTurnChange) {
                    bgColor = _turnColorAnimation.value;
                  }
                  return Container(
                    color: bgColor,
                    child: Center(
                      child: showBust
                          ? const Text(
                              'BUST',
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            )
                          : showTurnChange
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      players[currentPlayer],
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "It's your turn",
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  '${scores[currentPlayer]}',
                                  style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
                                ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Opacity(
                      opacity: i < (3 - dartsThrown) ? 1.0 : 0.2, // faded if dart used
                      child: SvgPicture.asset(
                        'assets/icons/dart-icon.svg',
                        width: 32,
                        height: 32,
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
            Expanded(
              flex: 6,
              child: Column(
                children: [
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
                            itemCount: 22,
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
                                  child: const Text('Bull', style: TextStyle(fontSize: 14)),
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