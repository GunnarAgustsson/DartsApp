import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/screens/options_screen.dart'; // for CheckoutRule

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
  bool _showNextList = false;
  late CheckoutRule _checkoutRule;

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

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _checkoutRule = CheckoutRule.values[prefs.getInt('checkoutRule') ?? 0];
      });
    });
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

  String _checkoutRuleLabel(CheckoutRule rule) {
    switch (rule) {
      case CheckoutRule.doubleOut:
        return 'Standard Double-Out';
      case CheckoutRule.extendedOut:
        return 'Extended Out';
      case CheckoutRule.exactOut:
        return 'Exactly 0';
      case CheckoutRule.openFinish:
        return 'Open Finish';
    }
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

      switch (_checkoutRule) {
        case CheckoutRule.doubleOut:
          if (afterScore < 0 || afterScore == 1) {
            isBust = true;
          } else if (afterScore == 0 && !(isDouble || isBull)) {
            isBust = true;
          } else if (afterScore == 0) {
            isWinningThrow = true;
          }
          break;
        case CheckoutRule.extendedOut:
          if (afterScore < 0 || afterScore == 1) {
            isBust = true;
          } else if (afterScore == 0 && !(isDouble || isBull || multiplier == 3)) {
            isBust = true;
          } else if (afterScore == 0) {
            isWinningThrow = true;
          }
          break;
        case CheckoutRule.exactOut:
          if (afterScore < 0 || afterScore == 1) {
            isBust = true;
          } else if (afterScore == 0) {
            isWinningThrow = true;
          }
          break;
        case CheckoutRule.openFinish:
          if (afterScore <= 0) {
            isWinningThrow = true;
          }
          break;
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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final double widthScale = width / 390;   // 390 is a typical mobile width
    final double heightScale = height / 844; // 844 is a typical mobile height
    final double scale = widthScale < heightScale ? widthScale : heightScale;

    final double playerCardHeight = height * 0.35;
    final double gridButtonHeight = 42 * scale;
    final double gridButtonWidth = 72 * scale;
    final double sectionSpacing = 10 * scale;
    final double betweenButtonSpacing = 10 * scale;

    final double playerNameFontSize = 32 * scale;
    final double playerScoreFontSize = 64 * scale;
    final double dartIconSize = 32 * scale;
    final double possibleFinishFontSize = 16 * scale;
    final double overlayBustFontSize = 32 * scale;
    final double overlayTurnNameFontSize = 40 * scale;
    final double overlayTurnTextFontSize = 28 * scale;
    final double scoreButtonFontSize = 18 * scale;

    final double multiplierButtonWidth = 96 * scale;
    final double multiplierButtonHeight = 52 * scale;
    final double multiplierButtonFontSize = 20 * scale;

    final double missUndoButtonWidth = 124 * scale;
    final double missUndoButtonHeight = 42 * scale;
    final double missUndoButtonFontSize = 16 * scale;
    final double missUndoIconSize = 16 * scale;

    final ordered = List.generate(players.length, (i) => (currentPlayer + 1 + i) % players.length);
    final nextIndex = ordered.first;
    final gameLabel = '${widget.startingScore} (${_checkoutRuleLabel(_checkoutRule)})';

    return PopScope(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.grey[200],
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.home,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.grey),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              Text(
                gameLabel,
                style: TextStyle(
                  fontSize: 16 * scale,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                ),
              ),
            ],
          ),
          title: const SizedBox.shrink(), // no centered title
          iconTheme: IconThemeData(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey),
          actions: [
            GestureDetector(
              onTap: () => setState(() => _showNextList = !_showNextList),
              child: Padding(
                padding: EdgeInsets.only(right: 16 * scale),
                child: Center(
                  child: Text(
                    'Next: ${players[nextIndex]} (${scores[nextIndex]})',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: sectionSpacing),
                  SizedBox(
                    height: playerCardHeight,
                    child: Stack(
                      children: [
                        _buildPlayerInfoCard(
                          context,
                          playerNameFontSize: playerNameFontSize,
                          playerScoreFontSize: playerScoreFontSize,
                          dartIconSize: dartIconSize,
                          possibleFinishFontSize: possibleFinishFontSize,
                        ),
                        if (showBust || showTurnChange)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_bustController, _turnController]),
                              builder: (context, child) => _buildOverlayAnimation(
                                bustFontSize: overlayBustFontSize,
                                turnNameFontSize: overlayTurnNameFontSize,
                                turnTextFontSize: overlayTurnTextFontSize,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        SizedBox(height: sectionSpacing),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: multiplierButtonWidth,
                              height: multiplierButtonHeight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: multiplier == 2 ? Colors.blue : null,
                                  textStyle: TextStyle(fontSize: multiplierButtonFontSize),
                                ),
                                onPressed: () => _setMultiplier(2),
                                child: const Text('x2'),
                              ),
                            ),
                            SizedBox(width: betweenButtonSpacing),
                            SizedBox(
                              width: multiplierButtonWidth,
                              height: multiplierButtonHeight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: multiplier == 3 ? Colors.blue : null,
                                  textStyle: TextStyle(fontSize: multiplierButtonFontSize),
                                ),
                                onPressed: () => _setMultiplier(3),
                                child: const Text('x3'),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: sectionSpacing),
                        ...List.generate(4, (row) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: betweenButtonSpacing),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (col) {
                                int number = row * 5 + col + 1;
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 3 * scale),
                                  child: SizedBox(
                                    width: gridButtonWidth,
                                    height: gridButtonHeight,
                                    child: _buildScoreButton(
                                      number,
                                      fontSize: scoreButtonFontSize,
                                      scale: scale,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                        Padding(
                          padding: EdgeInsets.only(bottom: sectionSpacing),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: gridButtonWidth + 8 * scale),
                              SizedBox(
                                width: gridButtonWidth,
                                height: gridButtonHeight,
                                child: _buildScoreButton(
                                  25,
                                  label: '25',
                                  fontSize: scoreButtonFontSize,
                                  scale: scale,
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              SizedBox(
                                width: gridButtonWidth,
                                height: gridButtonHeight,
                                child: _buildScoreButton(
                                  50,
                                  label: 'Bull',
                                  fontSize: scoreButtonFontSize * 0.85,
                                  scale: scale,
                                ),
                              ),
                              SizedBox(width: gridButtonWidth + 8 * scale),
                            ],
                          ),
                        ),
                        SizedBox(height: sectionSpacing * 2),
                        Padding(
                          padding: EdgeInsets.only(top: 0, bottom: 24 * scale),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: missUndoButtonWidth,
                                height: missUndoButtonHeight,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    textStyle: TextStyle(fontSize: missUndoButtonFontSize),
                                  ),
                                  onPressed: (isTurnChanging || showBust) ? null : () => _score(0),
                                  icon: Icon(Icons.cancel_outlined, size: missUndoIconSize),
                                  label: const Text('Miss'),
                                ),
                              ),
                              SizedBox(width: betweenButtonSpacing),
                              SizedBox(
                                width: missUndoButtonWidth,
                                height: missUndoButtonHeight,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    textStyle: TextStyle(fontSize: missUndoButtonFontSize),
                                    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                                  ),
                                  onPressed: (isTurnChanging || showBust) ? null : _undoLastThrow,
                                  icon: Icon(Icons.undo, size: missUndoIconSize),
                                  label: const Text('Undo'),
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
            if (_showNextList)
              Positioned(
                top: kToolbarHeight,
                left: 16 * scale,
                right: 16 * scale,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: players.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final name = shortenName(entry.value, maxLength: 12);
                      final pts = scores[idx];
                      final isCurrent = idx == currentPlayer;
                      final nextIndex = (currentPlayer + 1) % players.length;
                      final isUpcoming = idx == nextIndex;

                      return ListTile(
                        dense: true,
                        leading: isCurrent
                            ? Icon(Icons.arrow_right, color: Colors.green)
                            : SizedBox(width: 24 * scale),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isUpcoming
                                ? Colors.blue       
                                : isCurrent
                                    ? Colors.green    
                                    : null,           
                          ),
                        ),
                        trailing: Text('$pts'),
                        onTap: () => setState(() => _showNextList = false),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfoCard(
    BuildContext context, {
    required double playerNameFontSize,
    required double playerScoreFontSize,
    required double dartIconSize,
    required double possibleFinishFontSize,
  }) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.symmetric(vertical: 16 * (playerNameFontSize / 42), horizontal: 24 * (playerNameFontSize / 42)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16 * (playerNameFontSize / 42)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8 * (playerNameFontSize / 42),
              offset: Offset(0, 2 * (playerNameFontSize / 42)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shortenName(players[currentPlayer], maxLength: 12),
              style: TextStyle(fontSize: playerNameFontSize, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8 * (playerNameFontSize / 42)),
            Text(
              '${scores[currentPlayer]}',
              style: TextStyle(fontSize: playerScoreFontSize, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8 * (playerNameFontSize / 42)),
            _buildDartIcons(context, iconSize: dartIconSize),
            SizedBox(height: 8 * (playerNameFontSize / 42)),
            _buildPossibleFinish(fontSize: possibleFinishFontSize),
          ],
        ),
      ),
    );
  }

  Widget _buildDartIcons(BuildContext context, {double iconSize = 32}) {
    final recent = currentGame.throws.reversed
      .takeWhile((t) => t.player == players[currentPlayer])
      .take(3)
      .toList()
      .reversed
      .toList();

    final int shown = recent.length;
    final int totalSlots = 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var t in recent) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4 * (iconSize / 32)),
            child: Text(
              t.value == 0
                ? 'M'
                : t.value == 50
                  ? 'Bull'
                  : t.multiplier == 2
                    ? 'D${t.value}'
                    : t.multiplier == 3
                      ? 'T${t.value}'
                      : '${t.value}',
              style: TextStyle(
                fontSize: iconSize * 0.8,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          )
        ],
        for (int i = shown; i < totalSlots; i++) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4 * (iconSize / 32)),
            child: SvgPicture.asset(
              'assets/icons/dart-icon.svg',
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                BlendMode.srcIn,
              ),
            ),
          )
        ]
      ],
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

  Widget _buildOverlayAnimation({
    required double bustFontSize,
    required double turnNameFontSize,
    required double turnTextFontSize,
  }) {
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
        borderRadius: BorderRadius.circular(16 * (bustFontSize / 72)),
      ),
      child: Center(
        child: showBust
            ? Text(
                'BUST',
                style: TextStyle(
                  fontSize: bustFontSize,
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
                        '${players[currentPlayer]} scored: ${_lastTurnPoints()}',
                        style: TextStyle(
                          fontSize: turnNameFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8 * (turnNameFontSize / 40)),
                      Text(
                        _lastTurnLabels(),
                        style: TextStyle(
                          fontSize: turnTextFontSize,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8 * (turnNameFontSize / 40)),
                      Text(
                        '${players[nextPlayer]} it\'s your turn!',
                        style: TextStyle(
                          fontSize: turnNameFontSize,
                          fontWeight: FontWeight.bold,
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
      style: ElevatedButton.styleFrom(
        textStyle: TextStyle(fontSize: fontSize),
        padding: EdgeInsets.symmetric(vertical: 8 * scale),
      ),
      onPressed: (isTurnChanging || showBust) ? null : () => _score(value),
      child: Text(label ?? '$value', style: TextStyle(fontSize: fontSize)),
    );
  }

  int _lastTurnPoints() {
    final prev = players[currentPlayer];
    final lastThrows = currentGame.throws.reversed
      .takeWhile((t) => t.player == prev)
      .take(3)
      .toList();
    return lastThrows.fold(0, (sum, t) {
      final hit = (t.value == 25 || t.value == 50) ? t.value : t.value * t.multiplier;
      return sum + hit;
    });
  }

  String _lastTurnLabels() {
    final prev = players[currentPlayer];
    final last = currentGame.throws.reversed
      .takeWhile((t) => t.player == prev)
      .take(3)
      .toList()
      .reversed;
    return last.map((t) {
      if (t.value == 0) return 'M';
      if (t.value == 50) return 'Bull';
      if (t.multiplier == 2) return 'D${t.value}';
      if (t.multiplier == 3) return 'T${t.value}';
      return '${t.value}';
    }).join(' ');
  }
}