import 'package:flutter/material.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/widgets/score_button.dart';
import 'package:dars_scoring_app/widgets/overlay_animation.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:dars_scoring_app/widgets/player_info_card.dart';

/// The main game screen for “traditional” scoring (e.g. 301/501/X01).
/// Splits UI into:
///  - Player info card (score + last darts + possible finish)
///  - Multiplier selector (x1/x2/x3)
///  - Score grid (1–20, 25, Bull)
///  - Miss/Undo row
///  - Overlay animations for busts and turn changes
class GameScreen extends StatefulWidget {
  final int startingScore;
  final List<String> players;
  final GameHistory? gameHistory;
  /// Optional initial checkout rule; if provided, it overrides persisted preference.
  final CheckoutRule? initialRule;

  const GameScreen({
    super.key,
    required this.startingScore,
    required this.players,
    this.gameHistory,
    this.initialRule,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  // ---- 1) Animation controllers for bust & turn-change overlays ----
  late AnimationController _bustController;
  late Animation<Color?> _bustColorAnim;
  late AnimationController _turnController;
  late Animation<Color?> _turnColorAnim;

  // ---- 2) Game logic controller (abstracts scoring, history, rules) ----
  late final TraditionalGameController _ctrl;

  // Toggle for showing the “next player” dropdown
  bool _showNextList = false;

  bool _hasShownFinishDialog = false; // ensure we only show once

  @override
  void initState() {
    super.initState();
    _ctrl = TraditionalGameController(
      startingScore: widget.startingScore,
      players: widget.players,
      resumeGame: widget.gameHistory,
      initialRule: widget.initialRule,
    )..addListener(_onStateChanged);

    // Configure the “BUST” overlay animation (red flash)
    _bustController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bustColorAnim = ColorTween(begin: Colors.red, end: Colors.red)
        .animate(_bustController);

    // Configure the “Turn Change” overlay animation (blue flash)
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _turnColorAnim = ColorTween(begin: Colors.blue, end: Colors.blue)
        .animate(_turnController);
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _bustController.dispose();
    _turnController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// Called whenever our game logic (TraditionalGameController) notifies.
  /// Starts the appropriate animation and triggers a rebuild.
  void _onStateChanged() {
    setState(() {});

    if (_ctrl.showBust) _bustController.forward(from: 0);
    if (_ctrl.showTurnChange) _turnController.forward(from: 0);

    // only one unified popup per finish
    if (_ctrl.showPlayerFinished && !_hasShownFinishDialog) {
      _hasShownFinishDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFinishDialog(_ctrl.lastFinisher!);
      });
    }
  }

  Future<void> _showFinishDialog(String finisher) {
    final remaining = _ctrl.activePlayers.length;
    final title = remaining > 0
        ? 'Congratulations, $finisher!'
        : 'Game Over';
    final content = remaining > 0
        ? Text('$finisher has finished!\nRemaining: ${_ctrl.activePlayers.join(", ")}')
        : const Text('All players have finished.');

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          if (remaining > 0)
            TextButton(
              child: const Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
                _ctrl.clearPlayerFinishedFlag();
                // allow next finish to show again
                _hasShownFinishDialog = false;
              },
            ),
          TextButton(
            child: const Text('Play Again'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    startingScore: widget.startingScore,
                    players: widget.players,
                  ),
                ),
              );
            },
          ),
          TextButton(
            child: const Text('Main Menu'),
            onPressed: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final act = _ctrl.activePlayers;
    // GUARD: if empty, don’t index into act[curIdx]
    if (act.isEmpty) {
      return const Scaffold(
        body: SizedBox.expand(),
      );
    }

    final curIdx = _ctrl.activeCurrentIndex;
    final nxtIdx = _ctrl.activeNextIndex;
    final actScores = act.map((p) => _ctrl.scoreFor(p)).toList();

    final showBust = _ctrl.showBust;
    final showTurnChange = _ctrl.showTurnChange;
    final isTurnChanging = _ctrl.isTurnChanging;

    // Compute next player index for UI hints
    final gameLabel = '${widget.startingScore}-pt Game';

    // ---- 4) Responsive layout constants ----
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final scale = width / 390;

    // Heights, widths, font sizes scaled relative to a base iPhone screen width
    final playerCardHeight = height * 0.35;
    final gridButtonHeight = 42 * scale;
    final gridButtonWidth = 72 * scale;
    final sectionSpacing = 10 * scale;
    final betweenButtonSpacing = 10 * scale;
    final playerNameFontSize = 32 * scale;
    final playerScoreFontSize = 64 * scale;
    final dartIconSize = 32 * scale;
    final possibleFinishFontSize = 16 * scale;
    final overlayBustFontSize = 32 * scale;
    final overlayTurnNameFontSize = 40 * scale;
    final overlayTurnTextFontSize = 28 * scale;
    final scoreButtonFontSize = 18 * scale;
    final multiplierButtonWidth = 96 * scale;
    final multiplierButtonHeight = 52 * scale;
    final multiplierButtonFontSize = 20 * scale;
    final missUndoButtonWidth = 124 * scale;
    final missUndoButtonHeight = 42 * scale;
    final missUndoButtonFontSize = 16 * scale;
    final missUndoIconSize = 16 * scale;

    // ---- 5) Build the Scaffold with AppBar + Body ----
    return Scaffold(
      // AppBar with home button & game label, plus “Next” toggle
      appBar: AppBar(
        // Use colors from theme
        // backgroundColor and iconTheme come from AppBarTheme in ThemeData
        // Leading: home icon and label
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: Text(gameLabel),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => setState(() => _showNextList = !_showNextList),
            child: Text(
              'Next: ${shortenName(act[nxtIdx], maxLength: 12)} (${actScores[nxtIdx]})',
            ),
          ),
        ],
      ),

      // Body stack: main game UI + optional next-player list
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: sectionSpacing),

                // ---- 5a) Player Info Card + Overlay Stack ----
                SizedBox(
                  height: playerCardHeight,
                  child: Stack(
                    children: [
                      // Core player info (score, name, last darts, possible finish)
                      PlayerInfoCard(
                        ctrl: _ctrl,
                        playerNameFontSize: playerNameFontSize,
                        playerScoreFontSize: playerScoreFontSize,
                        dartIconSize: dartIconSize,
                        possibleFinishFontSize: possibleFinishFontSize,
                      ),

                      // Overlay (bust or turn-change) above the card
                      if (showBust || showTurnChange)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            // Listen to both controllers so color.value updates
                            animation: Listenable.merge(
                                [_bustController, _turnController]),
                            builder: (_, __) {
                              // Choose red or blue flash
                              final bg = showBust
                                  ? _bustColorAnim.value!
                                  : _turnColorAnim.value!;
                              return OverlayAnimation(
                                showBust: showBust,
                                showTurnChange: showTurnChange,
                                bgColor: bg,
                                lastTurnPoints:
                                    _ctrl.lastTurnPoints(),
                                lastTurnLabels:
                                    _ctrl.lastTurnLabels(),
                                nextPlayerName:
                                    act[nxtIdx],
                                bustFontSize: overlayBustFontSize,
                                turnNameFontSize:
                                    overlayTurnNameFontSize,
                                turnTextFontSize:
                                    overlayTurnTextFontSize,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // ---- 5b) Controls Column (Multiplier + Grid + Miss/Undo) ----
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      SizedBox(height: sectionSpacing),

                      // Multiplier buttons (x2, x3)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: multiplierButtonWidth,
                            height: multiplierButtonHeight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _ctrl.multiplier == 2
                                        ? Colors.blue
                                        : null,
                                textStyle: TextStyle(
                                    fontSize:
                                        multiplierButtonFontSize),
                              ),
                              onPressed: () =>
                                  _ctrl.setMultiplier(2),
                              child: const Text('x2'),
                            ),
                          ),
                          SizedBox(width: betweenButtonSpacing),
                          SizedBox(
                            width: multiplierButtonWidth,
                            height: multiplierButtonHeight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _ctrl.multiplier == 3
                                        ? Colors.blue
                                        : null,
                                textStyle: TextStyle(
                                    fontSize:
                                        multiplierButtonFontSize),
                              ),
                              onPressed: () =>
                                  _ctrl.setMultiplier(3),
                              child: const Text('x3'),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: sectionSpacing),

                      // Number grid (1–20)
                      ...List.generate(4, (row) {
                        return Padding(
                          padding:
                              EdgeInsets.only(bottom: betweenButtonSpacing),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children:
                                List.generate(5, (col) {
                              final number =
                                  row * 5 + col + 1;
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        3 * scale),
                                child: SizedBox(
                                  width: gridButtonWidth,
                                  height: gridButtonHeight,
                                  child: ScoreButton(
                                    value: number,
                                    label: '$number',
                                    fontSize:
                                        scoreButtonFontSize,
                                    disabled: isTurnChanging ||
                                        showBust,
                                    onPressed: () =>
                                        _ctrl.score(number),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),

                      // Row for 25 and Bull
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: sectionSpacing),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: gridButtonWidth +
                                    8 * scale),
                            SizedBox(
                              width: gridButtonWidth,
                              height: gridButtonHeight,
                              child: ScoreButton(
                                value: 25,
                                label: '25',
                                fontSize:
                                    scoreButtonFontSize,
                                disabled: isTurnChanging ||
                                    showBust,
                                onPressed: () =>
                                    _ctrl.score(25),
                              ),
                            ),
                            SizedBox(width: 8 * scale),
                            SizedBox(
                              width: gridButtonWidth,
                              height: gridButtonHeight,
                              child: ScoreButton(
                                value: 50,
                                label: 'Bull',
                                fontSize:
                                    scoreButtonFontSize *
                                        0.85,
                                disabled: isTurnChanging ||
                                    showBust,
                                onPressed: () =>
                                    _ctrl.score(50),
                              ),
                            ),
                            SizedBox(
                                width: gridButtonWidth +
                                    8 * scale),
                          ],
                        ),
                      ),

                      // Miss and Undo buttons
                      SizedBox(height: sectionSpacing * 2),
                      Padding(
                        padding: EdgeInsets.only(
                            top: 0, bottom: 24 * scale),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            // Miss = score(0)
                            SizedBox(
                              width: missUndoButtonWidth,
                              height: missUndoButtonHeight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.red,
                                  foregroundColor:
                                      Colors.white,
                                  textStyle: TextStyle(
                                      fontSize:
                                          missUndoButtonFontSize),
                                ),
                                onPressed:
                                    (isTurnChanging ||
                                            showBust)
                                        ? null
                                        : () =>
                                            _ctrl.score(0),
                                icon: Icon(
                                    Icons.cancel_outlined,
                                    size: missUndoIconSize),
                                label: const Text('Miss'),
                              ),
                            ),

                            SizedBox(
                                width:
                                    betweenButtonSpacing),

                            // Undo = undoLastThrow()
                            SizedBox(
                              width: missUndoButtonWidth,
                              height: missUndoButtonHeight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.red,
                                  foregroundColor:
                                      Colors.white,
                                  textStyle:
                                      TextStyle(
                                          fontSize:
                                              missUndoButtonFontSize),
                                  padding:
                                      EdgeInsets.symmetric(
                                          horizontal:
                                              8 * scale),
                                ),
                                onPressed:
                                    (isTurnChanging ||
                                            showBust)
                                        ? null
                                        : _ctrl
                                            .undoLastThrow,
                                icon: Icon(Icons.undo,
                                    size:
                                        missUndoIconSize),
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

          // ---- 5c) Next-player dropdown overlay ----
          if (_showNextList)
            Positioned(
              top: kToolbarHeight,
              left: 16 * scale,
              right: 16 * scale,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8 * scale),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: act
                      .asMap()
                      .entries
                      .map((entry) {
                    final idx = entry.key;
                    final name = shortenName(
                        entry.value,
                        maxLength: 12);
                    final pts = actScores[idx];
                    final isCurrent =
                        idx == curIdx;
                    final isUpcoming =
                        idx == nxtIdx;

                    return ListTile(
                      dense: true,
                      leading: isCurrent
                          ? Icon(Icons.arrow_right,
                              color: Colors.green)
                          : SizedBox(
                              width: 24 * scale),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isUpcoming
                              ? Colors.blue
                              : isCurrent
                                  ? Colors.green
                                  : null,
                        ),
                      ),
                      trailing: Text('$pts'),
                      onTap: () => setState(
                          () => _showNextList = false),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}