import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/theme/app_dimensions.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/widgets/overlay_animation.dart';
import 'package:dars_scoring_app/widgets/scoring_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The main game screen for "traditional" scoring (e.g. 301/501/X01).
/// Splits UI into:
///  - Player info card (score + last darts + possible finish)
///  - Multiplier selector (x1/x2/x3)
///  - Score grid (1–20, 25, Bull)
///  - Miss/Undo row
///  - Overlay animations for busts and turn changes
class GameScreen extends StatefulWidget {

  const GameScreen({
    super.key,
    required this.startingScore,
    required this.players,
    this.gameHistory,
    this.checkoutRule,
    this.randomOrder = false,
  });
  final int startingScore;
  final List<String> players;
  final GameHistory? gameHistory;
  final CheckoutRule? checkoutRule;
  final bool randomOrder;

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
      randomOrder: widget.randomOrder,
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
        : '🎉 Game Complete!';
    final content = remaining > 0
        ? Text(
            '$finisher has finished!\nRemaining: ${_ctrl.activePlayers.join(", ")}',
            style: theme.textTheme.bodyMedium,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'All players have finished.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Final Order:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.players.asMap().entries.map((entry) {
                final position = entry.key + 1;
                final player = entry.value;
                final suffix = position == 1 ? '🥇' : position == 2 ? '🥈' : position == 3 ? '🥉' : '';
                return Text(
                  '$position. $player $suffix',
                  style: theme.textTheme.bodyMedium,
                );
              }),
            ],
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text(
              'Play Again', 
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              
              // Determine new player order based on randomOrder setting
              List<String> newPlayerOrder;
              if (widget.randomOrder) {
                // Randomize player order for new game
                newPlayerOrder = List.from(widget.players);
                newPlayerOrder.shuffle();
              } else {
                // Shift player order: first player becomes last
                newPlayerOrder = List.from(widget.players);
                if (newPlayerOrder.isNotEmpty) {
                  final firstPlayer = newPlayerOrder.removeAt(0);
                  newPlayerOrder.add(firstPlayer);
                }
              }
              
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    startingScore: widget.startingScore,
                    players: newPlayerOrder,
                    checkoutRule: widget.checkoutRule,
                    randomOrder: widget.randomOrder,
                  ),
                ),
              );
            },
          ),
          TextButton(
            child: Text('Back to Menu', style: theme.textTheme.labelMedium),
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

    // ---- 4) Responsive layout constants ----
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final isLandscape = width > height;
    
    // Theme
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // AppBar with consistent styling like Killer game
      appBar: AppBar(
        title: Text('${widget.startingScore}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        // Leading widget: home icon (pop to root)
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
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
                // Scoring buttons (replaces multiplier buttons, score grid, and special actions)
                Expanded(
                  child: ScoringButtons(
                    config: ScoringButtonsConfig(
                      showMultipliers: true,
                      show25Button: true,
                      showBullButton: true,
                      showMissButton: true,
                      showUndoButton: true,
                      disabled: isDisabled,
                    ),
                    onScore: (score, label) => _ctrl.score(score, label),
                    onUndo: _ctrl.undoLastThrow,
                  ),
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
                // Scoring buttons (replaces multiplier buttons, keypad, and special actions)
                Expanded(
                  child: ScoringButtons(
                    config: ScoringButtonsConfig(
                      showMultipliers: true,
                      show25Button: true,
                      showBullButton: true,
                      showMissButton: true,
                      showUndoButton: true,
                      disabled: isDisabled,
                    ),
                    onScore: (score, label) => _ctrl.score(score, label),
                    onUndo: _ctrl.undoLastThrow,
                  ),
                ),
              ],
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
        duration: _ctrl.overlayAnimationDuration,
        child: OverlayAnimation(
          showBust: showBust,
          showTurnChange: showTurnChange,
          lastTurnPoints: _ctrl.lastTurnPoints(),
          lastTurnLabels: _ctrl.lastTurnLabels(),
          nextPlayerName: nextPlayerName ?? '',
          animationDuration: _ctrl.overlayAnimationDuration,
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
    final isTablet = size.shortestSide >= 600;
    
    return Positioned(
      top: 0,
      left: AppDimensions.paddingM,
      right: AppDimensions.paddingM,
      child: Card(
        elevation: AppDimensions.elevationM,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
            width: 1,
          ),
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
            final avgScore = _ctrl.averageScoreFor(entry.value).toStringAsFixed(1);
            final isCurrent = idx == curIdx;
            final isUpcoming = idx == nxtIdx;

            return Container(
              decoration: BoxDecoration(
                color: isCurrent 
                    ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                dense: true,
                leading: isCurrent
                    ? Icon(
                        Icons.arrow_right, 
                        color: theme.colorScheme.primary,
                        size: isTablet ? 28 : 24,
                      )
                    : SizedBox(width: isTablet ? 28 : 24),
                title: Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isUpcoming 
                        ? theme.colorScheme.secondary 
                        : isCurrent
                            ? theme.colorScheme.primary
                            : null,
                  ),
                ),
                trailing: Text(
                  '$pts (Avg: $avgScore)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isCurrent 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () => setState(() => _showNextList = false),
              ),
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
    final isTablet = size.shortestSide >= 600;

    return Center(
      child: Container(
        width: isLandscape 
            ? double.infinity
            : size.width * 0.9,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
          border: Border.all(
            color: theme.colorScheme.primary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
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
                              '${shortenName(playerName, maxLength: 15)}\'s Turn',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Avg: ${average.toStringAsFixed(1)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${shortenName(playerName, maxLength: 15)}\'s Turn',
                              textAlign: TextAlign.left,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
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
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            if (finish != null) const SizedBox(height: AppDimensions.marginS),

            // Darts left icons with improved styling
            Expanded(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Darts: ',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: isTablet ? 18 : 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...List.generate(3, (index) {
                      final isThrown = index < dartsThrownInTurn;
                      final dartLabels = _ctrl.currentTurnDartLabels;
                      final label = isThrown && index < dartLabels.length
                          ? dartLabels[index]
                          : null;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Container(
                          width: isTablet ? 32 : 28,
                          height: isTablet ? 32 : 28,
                          decoration: BoxDecoration(
                            color: isThrown
                                ? theme.colorScheme.primary.withOpacity(0.8)
                                : theme.colorScheme.primary.withOpacity(0.2),
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/dart-icon.svg',
                                width: isTablet ? 20 : 18,
                                height: isTablet ? 20 : 18,
                                colorFilter: ColorFilter.mode(
                                  isThrown
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              if (isThrown && label != null)
                                Positioned(
                                  bottom: 2,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isTablet ? 10 : 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
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