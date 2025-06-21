import 'dart:math';

import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/theme/app_dimensions.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/widgets/overlay_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/score_button.dart';

/// The main game screen for "traditional" scoring (e.g. 301/501/X01).
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
  final CheckoutRule? checkoutRule;

  const GameScreen({
    super.key,
    required this.startingScore,
    required this.players,
    this.gameHistory,
    this.checkoutRule,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  // ---- 1) Animation controllers for bust & turn-change overlays ----
  // (Removed - animation is now handled by state flags from the controller)

  // ---- 2) Game logic controller (abstracts scoring, history, rules) ----
  late final TraditionalGameController _ctrl;

  // Toggle for showing the "next player" dropdown
  bool _showNextList = false;

  // (Removed - _isAnimating is no longer needed)
  bool _hasShownFinishDialog = false; // ensure we only show once

  @override
  void initState() {
    super.initState();
    _ctrl = TraditionalGameController(
      startingScore: widget.startingScore,
      players: widget.players,
      resumeGame: widget.gameHistory,
      checkoutRule: widget.checkoutRule,
    )..addListener(_onStateChanged);
    
    // (Removed - animation controller setup is no longer needed)
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _ctrl.dispose();
    super.dispose();
  }

  /// Called whenever our game logic (TraditionalGameController) notifies.
  /// Triggers a rebuild and handles showing finish dialogs.
  void _onStateChanged() {
    setState(() {});

    // (Removed - animation controller triggers are no longer needed)

    // only one unified popup per finish
    if (_ctrl.showPlayerFinished && !_hasShownFinishDialog) {
      _hasShownFinishDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFinishDialog(_ctrl.lastFinisher!);
      });
    }
  }

  Future<void> _showFinishDialog(String finisher) {
    final theme = Theme.of(context);
    final remaining = _ctrl.activePlayers.length;
    final title = remaining > 0
        ? 'Congratulations, $finisher!'
        : 'Game Over';
    final content = remaining > 0
        ? Text(
            '$finisher has finished!\nRemaining: ${_ctrl.activePlayers.join(", ")}',
            style: theme.textTheme.bodyMedium,
          )
        : Text(
            'All players have finished.',
            style: theme.textTheme.bodyMedium,
          );

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title, style: theme.textTheme.titleLarge),
        content: content,
        actions: [
          if (remaining > 0)
            TextButton(
              child: Text('Continue', style: theme.textTheme.labelMedium),
              onPressed: () {
                Navigator.of(context).pop();
                _ctrl.clearPlayerFinishedFlag();
                // allow next finish to show again
                _hasShownFinishDialog = false;
              },
            ),
          TextButton(
            child: Text('Play Again', style: theme.textTheme.labelMedium),
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
            child: Text('Main Menu', style: theme.textTheme.labelMedium),
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
    // GUARD: if empty, don't index into act[curIdx]
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
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final isLandscape = width > height;
    
    // Theme
    final theme = Theme.of(context);
      // Base scale factor for responsive sizing - using height-based scaling now

    return Scaffold(
      // AppBar with home button & game label, plus "Next" toggle
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: AppDimensions.elevationS,
        // Leading widget: home icon + label (pop to root)
        leading: IconButton(
          icon: Icon(
            Icons.home,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        // Title
        title: Text(
          gameLabel,
          style: theme.textTheme.titleMedium,
        ),
        // "Next" button in the AppBar actions
        actions: [
          GestureDetector(
            onTap: () => setState(() => _showNextList = !_showNextList),
            child: Padding(
              padding: const EdgeInsets.only(right: AppDimensions.paddingM),
              child: Center(
                child: Text(
                  'Next: ${shortenName(act[nxtIdx], maxLength: 12)} (${actScores[nxtIdx]})',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),

      // Body stack: main game UI + optional next-player list
      body: Stack(
        children: [
          SafeArea(
            child: isLandscape 
                ? _buildLandscapeLayout(context, showBust, showTurnChange, isTurnChanging, act, curIdx, nxtIdx, actScores)
                : _buildPortraitLayout(context, showBust, showTurnChange, isTurnChanging, act, curIdx, nxtIdx, actScores),
          ),

          // ---- 5c) Next-player dropdown overlay ----
          if (_showNextList)
            _buildNextPlayersList(act, curIdx, nxtIdx, actScores),
        ],
      ),
    );
  }
  
  /// Build landscape layout with player info on left, controls on right
  Widget _buildLandscapeLayout(
    BuildContext context,
    bool showBust,
    bool showTurnChange,
    bool isTurnChanging,
    List<String> activePlayers,
    int curIdx,
    int nxtIdx,
    List<int> actScores,
  ) {
    final theme = Theme.of(context);
    final isDisabled = isTurnChanging || showBust || showTurnChange;
    final nextPlayerName = activePlayers[nxtIdx];
    
    return Row(
      children: [
        // Left side - Player info
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Core player info
                      _buildPlayerInfoCard(
                        context,
                        activePlayers[curIdx],
                        actScores[curIdx],
                        _ctrl.averageScoreFor(activePlayers[curIdx]),
                        _ctrl.dartsThrown,
                        _getBestFinish(actScores[curIdx], 3 - _ctrl.dartsThrown),
                      ),
                      
                      // Overlay animations
                      _buildOverlayAnimation(showBust, showTurnChange, nextPlayerName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Vertical divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
        
        // Right side - Controls
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              children: [
                // Multiplier buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                  child: _buildMultiplierButtons(isTurnChanging, showBust),
                ),
                
                // Score grid
                Expanded(
                  flex: 3,
                  child: _buildKeypad(isDisabled),
                ),
                const SizedBox(height: AppDimensions.marginM),
                
                // Special Actions Area
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.paddingM),
                  child: _buildSpecialActions(isDisabled),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Build portrait layout with player info on top, controls below
  Widget _buildPortraitLayout(
    BuildContext context,
    bool showBust,
    bool showTurnChange,
    bool isTurnChanging,
    List<String> activePlayers,
    int curIdx,
    int nxtIdx,
    List<int> actScores,
  ) {
    final size = MediaQuery.of(context).size;
    final isDisabled = isTurnChanging || showBust || showTurnChange;
    final nextPlayerName = activePlayers[nxtIdx];

    // Define flex factors for layout proportions
    const playerInfoFlex = 3;
    const controlsFlex = 7;

    return Column(
      children: [
        // Player Info Card
        Expanded(
          flex: playerInfoFlex,
          child: Padding(
            padding: const EdgeInsets.only(top: AppDimensions.marginM),
            child: Stack(
              children: [
                _buildPlayerInfoCard(
                  context,
                  activePlayers[curIdx],
                  actScores[curIdx],
                  _ctrl.averageScoreFor(activePlayers[curIdx]),
                  _ctrl.dartsThrown,
                  _getBestFinish(actScores[curIdx], 3 - _ctrl.dartsThrown),
                ),
                _buildOverlayAnimation(showBust, showTurnChange, nextPlayerName),
              ],
            ),
          ),
        ),

        // Controls Area
        Expanded(
          flex: controlsFlex,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: Column(
              children: [
                // Multiplier Buttons
                SizedBox(
                  height: size.height * 0.07,
                  child: _buildMultiplierButtons(isTurnChanging, showBust),
                ),
                const SizedBox(height: AppDimensions.marginM),

                // Main Keypad Area
                Expanded(
                  flex: 3,
                  child: _buildKeypad(isDisabled),
                ),
                const SizedBox(height: AppDimensions.marginM),

                // Special Actions (25, Bull, Miss, Undo)
                SizedBox(
                  height: size.height * 0.08,
                  child: _buildSpecialActions(isDisabled),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypad(bool isDisabled) {
    return LayoutBuilder(builder: (context, constraints) {
      const crossAxisCount = 5;
      const mainAxisCount = 4; // 4 rows for numbers
      const hSpacing = AppDimensions.marginS;
      const vSpacing = AppDimensions.marginS;

      final buttonWidth = (constraints.maxWidth - (crossAxisCount - 1) * hSpacing) / crossAxisCount;
      final buttonHeight = (constraints.maxHeight - (mainAxisCount - 1) * vSpacing) / mainAxisCount;
      final side = min(buttonWidth, buttonHeight);
      final numberButtonSize = Size(side, side);

      List<Widget> keypadRows = [];
      // Generate number button rows
      for (int row = 0; row < 4; row++) {
        List<Widget> rowButtons = [];
        for (int col = 0; col < 5; col++) {
          final value = row * 5 + col + 1;
          rowButtons.add(
            Expanded(
              child: ScoreButton(
                value: value,
                onPressed: () => _ctrl.score(value),
                disabled: isDisabled,
                size: ScoreButtonSize.custom,
                customSize: numberButtonSize,
              ),
            ),
          );
          if (col < 4) {
            rowButtons.add(const SizedBox(width: hSpacing));
          }
        }
        keypadRows.add(Expanded(child: Row(children: rowButtons)));
        if (row < 3) {
          keypadRows.add(const SizedBox(height: vSpacing));
        }
      }

      return Column(children: keypadRows);
    });
  }

  /// Build multiplier row buttons
  Widget _buildMultiplierButtons(bool isTurnChanging, bool showBust) {
    final theme = Theme.of(context);
    final isDisabled = isTurnChanging || showBust;

    Widget buildButton(int multiplier, Color color, Color containerColor) {
      final isSelected = _ctrl.multiplier == multiplier;
      return Expanded(
        flex: 2,
        child: SizedBox(
          height: 55,
          child: isSelected
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.7),
                        color,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusL),
                      ),
                    ),
                    onPressed:
                        isDisabled ? null : () => _ctrl.setMultiplier(1),
                    child: Text(
                      'x$multiplier',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary),
                    ),
                  ),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusL),
                    ),
                  ),
                  onPressed:
                      isDisabled ? null : () => _ctrl.setMultiplier(multiplier),
                  child: Text('x$multiplier', style: const TextStyle(fontSize: 18)),
                ),
        ),
      );
    }

    return Row(
      children: [
        const Spacer(),
        buildButton(2, theme.colorScheme.secondary,
            theme.colorScheme.secondaryContainer),
        const SizedBox(width: AppDimensions.marginS),
        buildButton(
            3, theme.colorScheme.tertiary, theme.colorScheme.tertiaryContainer),
        const Spacer(),
      ],
    );
  }

  /// Build special action buttons (25, Bull, Miss, Undo)
  Widget _buildSpecialActions(bool isDisabled) {
    final theme = Theme.of(context);
    const buttonHeight = 65.0;

    return Row(
      children: [
        // 25 Button
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: const StadiumBorder(),
              ),
              onPressed: isDisabled ? null : () => _ctrl.score(25),
              child: const Text("25",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.marginS),
        // Bull Button
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: const StadiumBorder(),
              ),
              onPressed: isDisabled ? null : () => _ctrl.score(50),
              child: const Text("Bull",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.marginS),
        // Miss Button
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error, width: 2),
                shape: const StadiumBorder(),
              ),
              onPressed: isDisabled ? null : () => _ctrl.score(0),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Miss',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.marginS),
        // Undo Button
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error, width: 2),
                shape: const StadiumBorder(),
              ),
              onPressed: isDisabled ? null : _ctrl.undoLastThrow,
              icon: const Icon(Icons.undo),
              label: const Text('Undo',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  /// Build overlay for animations (bust or turn change)
  Widget _buildOverlayAnimation(
    bool showBust, 
    bool showTurnChange, 
    String? nextPlayerName
  ) {
    return Visibility(
      visible: showBust || showTurnChange,
      child: AnimatedOpacity(
        opacity: showBust || showTurnChange ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: OverlayAnimation(
          showBust: showBust,
          showTurnChange: showTurnChange,
          lastTurnPoints: _ctrl.lastTurnPoints(),
          lastTurnLabels: _ctrl.lastTurnLabels(),
          nextPlayerName: nextPlayerName ?? '',
        ),
      ),
    );
  }
  
  /// Build next players dropdown list
  Widget _buildNextPlayersList(
    List<String> activePlayers,
    int curIdx,
    int nxtIdx,
    List<int> actScores,
  ) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final scale = size.width / 390;
    
    return Positioned(
      top: 0,
      left: AppDimensions.paddingM,
      right: AppDimensions.paddingM,
      child: Card(
        elevation: AppDimensions.elevationM,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: activePlayers
              .asMap()
              .entries
              .map((entry) {
            final idx = entry.key;
            final name = shortenName(entry.value, maxLength: 12);
            final pts = actScores[idx];
            final avgScore = _ctrl.averageScoreFor(entry.value).toStringAsFixed(1); // Get average score
            final isCurrent = idx == curIdx;
            final isUpcoming = idx == nxtIdx;

            return ListTile(
              dense: true,
              leading: isCurrent
                  ? Icon(Icons.arrow_right, color: theme.colorScheme.primary)
                  : SizedBox(width: 24 * scale),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isUpcoming ? theme.colorScheme.secondary : null,
                ),
              ),
              trailing: Text(
                '$pts (Avg: $avgScore)', // Display current score and average score
                style: theme.textTheme.titleMedium?.copyWith(
                   color: isCurrent ? theme.colorScheme.primary : null,
                ),
              ),
              onTap: () => setState(() => _showNextList = false),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---- 6) Helper: Player info card (score + darts + possible finish) ----
  Widget _buildPlayerInfoCard(
    BuildContext context,
    String playerName,
    int score,
    double average,
    int dartsThrownInTurn,
    String? finish,
  ) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Center(
      child: Container(
        width: isLandscape 
            ? double.infinity
            : size.width * 0.9,
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.paddingM,
          horizontal: AppDimensions.paddingL,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top row: Player Name and Average
            Expanded(
              flex: 2,
              child: isLandscape
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              shortenName(playerName, maxLength: 15),
                              style: theme.textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Avg: ${average.toStringAsFixed(1)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              shortenName(playerName, maxLength: 15),
                              textAlign: TextAlign.left,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.marginM),
                        Expanded(
                          flex: 2,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Avg: ${average.toStringAsFixed(1)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppDimensions.marginS),

            // Current score - Use Expanded and FittedBox to make it scale
            Expanded(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  score.toString(),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.marginS),

            // Display possible finish
            if (finish != null)
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    'Finish: $finish',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            if (finish != null) const SizedBox(height: AppDimensions.marginS),

            // Darts left icons
            Expanded(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isThrown = index < dartsThrownInTurn;
                    final dartLabels = _ctrl.currentTurnDartLabels;
                    final label = isThrown && index < dartLabels.length
                        ? dartLabels[index]
                        : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/dart-icon.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              isThrown
                                  ? theme.colorScheme.onSurface
                                      .withOpacity(0.3)
                                  : theme.colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                          if (isThrown && label != null)
                            Text(
                              label,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getBestFinish(int score, int dartsLeft) {
    if (dartsLeft <= 0) return null;
    
    final options = bestCheckouts(
      score,
      dartsLeft,
      _ctrl.checkoutRule,
      limit: 1, 
    );

    if (options.isNotEmpty) {
      return options.first.join(' - ');
    }

    return null;
  }
}