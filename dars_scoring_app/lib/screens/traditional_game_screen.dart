import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';

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
  bool isTurnChanging = false;
  int? _pendingNextPlayer;

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
      begin: Colors.red, 
      end: Colors.red,   
    ).animate(_bustController);

    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _turnColorAnimation = ColorTween(
      begin: Colors.blue, 
      end: Colors.blue,   
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
            isTurnChanging = true;
            int temp = currentPlayer;
            do {
              temp = (temp + 1) % players.length;
            } while (_finishedPlayers.contains(players[temp]) && _finishedPlayers.length < players.length);
            _pendingNextPlayer = temp;
            showTurnChange = true;
            _turnController.forward(from: 0);
            Future.delayed(const Duration(seconds: 2), () {
              setState(() {
                currentPlayer = _pendingNextPlayer!;
                _pendingNextPlayer = null;
                showTurnChange = false;
                isTurnChanging = false;
                _turnController.reset();
              });
            });
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
          // Set winner if not already set
          if (currentGame.winner == null) {
            currentGame = GameHistory(
              id: currentGame.id,
              players: currentGame.players,
              createdAt: currentGame.createdAt,
              modifiedAt: DateTime.now(),
              throws: currentGame.throws,
              completedAt: null,
              gameMode: currentGame.gameMode,
              winner: players[currentPlayer],
            );
            _saveOrUpdateGameHistory();
          }
          if (_finishedPlayers.length == players.length) {
            currentGame.completedAt = DateTime.now();
            _saveOrUpdateGameHistory();
          }
          _showWinnerDialog(players[currentPlayer]);
        } else {
          if (dartsThrown >= 3) {
            dartsThrown = 0;
            isTurnChanging = true;
            int temp = currentPlayer;
            do {
              temp = (temp + 1) % players.length;
            } while (_finishedPlayers.contains(players[temp]) && _finishedPlayers.length < players.length);
            _pendingNextPlayer = temp;
            showTurnChange = true;
            _turnController.forward(from: 0);
            Future.delayed(const Duration(seconds: 2), () {
              setState(() {
                currentPlayer = _pendingNextPlayer!;
                _pendingNextPlayer = null;
                showTurnChange = false;
                isTurnChanging = false;
                _turnController.reset();
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
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final scale = width / 390; // 390 is a typical mobile width, adjust as needed

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200],
          leading: IconButton(
            icon: Icon(Icons.home, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          title: Text(
            'Darts Game (${widget.startingScore})',
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          ),
          iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 350 * scale,
              child: Stack(
                children: [
                  _buildPlayerInfoCard(context, scale),
                  if (showBust || showTurnChange)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_bustController, _turnController]),
                        builder: (context, child) => _buildOverlayAnimation(scale),
                      ),
                    ),
                ],
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
                      SizedBox(width: 16 * scale),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: multiplier == 3 ? Colors.blue : null,
                        ),
                        onPressed: () => _setMultiplier(3),
                        child: const Text('x3'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.all(8 * scale),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 8 * scale,
                              crossAxisSpacing: 8 * scale,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: 22,
                            itemBuilder: (context, index) {
                              if (index < 20) {
                                return _buildScoreButton(index + 1, scale: scale);
                              } else if (index == 20) {
                                return _buildScoreButton(25, label: '25', scale: scale);
                              } else {
                                return _buildScoreButton(50, label: 'Bull', fontSize: 12 * scale, scale: scale);
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 0, bottom: 50 * scale),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 120 * scale, height: 40 * scale,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: (isTurnChanging || showBust) ? null : () => _score(0),
                                  icon: Icon(Icons.cancel_outlined, size: 20 * scale),
                                  label: Text('Miss', style: TextStyle(fontSize: 16 * scale)),
                                ),
                              ),
                              SizedBox(width: 16 * scale),
                              SizedBox(
                                width: 120 * scale, height: 40 * scale,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                                  ),
                                  onPressed: (isTurnChanging || showBust) ? null : _undoLastThrow,
                                  icon: Icon(Icons.undo, size: 20 * scale),
                                  label: Text('Undo', style: TextStyle(fontSize: 16 * scale)),
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

  Widget _buildPlayerInfoCard(BuildContext context, double scale) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.symmetric(vertical: 16 * scale, horizontal: 24 * scale),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8 * scale,
              offset: Offset(0, 2 * scale),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shortenName(players[currentPlayer], maxLength: 12),
              style: TextStyle(fontSize: 42 * scale, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8 * scale),
            Text(
              '${scores[currentPlayer]}',
              style: TextStyle(fontSize: 72 * scale, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8 * scale),
            _buildDartIcons(context, iconSize: 32 * scale),
            SizedBox(height: 8 * scale),
            _buildPossibleFinish(fontSize: 18 * scale),
          ],
        ),
      ),
    );
  }

  Widget _buildDartIcons(BuildContext context, {double iconSize = 32}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4 * (iconSize / 32)),
          child: Opacity(
            opacity: i < (3 - dartsThrown) ? 1.0 : 0.2,
            child: SvgPicture.asset(
              'assets/icons/dart-icon.svg',
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPossibleFinish({double fontSize = 18}) {
    final score = scores[currentPlayer];
    final dartsLeft = 3 - dartsThrown;
    final finishEntry = possibleFinishes[score];
    if (finishEntry != null && finishEntry['darts'] <= dartsLeft) {
      return Text(
        'Possible finish: ${finishEntry['finish']}',
        style: TextStyle(fontSize: fontSize, color: Colors.grey[600]),
      );
    } else {
      return Text(
        'No finish possible',
        style: TextStyle(fontSize: fontSize, color: Colors.grey[600]),
      );
    }
  }

  Widget _buildOverlayAnimation(double scale) {
    Color? bgColor = Colors.transparent;
    if (showBust) {
      bgColor = _bustColorAnimation.value;
    } else if (showTurnChange) {
      bgColor = _turnColorAnimation.value;
    }
    int nextPlayer = currentPlayer;
    if (showTurnChange && _pendingNextPlayer != null) {
      nextPlayer = _pendingNextPlayer!;
    }
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Center(
        child: showBust
            ? Text(
                'BUST',
                style: TextStyle(
                  fontSize: 72 * scale,
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
                        shortenName(players[nextPlayer], maxLength: 12),
                        style: TextStyle(
                          fontSize: 40 * scale,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        "It's your turn",
                        style: TextStyle(
                          fontSize: 28 * scale,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildScoreButton(int value, {String? label, double fontSize = 16, double scale = 1.0}) {
    return ElevatedButton(
      onPressed: (isTurnChanging || showBust) ? null : () => _score(value),
      child: Text(label ?? '$value', style: TextStyle(fontSize: fontSize * scale)),
    );
  }
}