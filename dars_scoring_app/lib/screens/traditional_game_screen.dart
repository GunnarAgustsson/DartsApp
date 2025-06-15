import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/widgets/score_button.dart';
import 'package:dars_scoring_app/widgets/overlay_animation.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/theme/app_dimensions.dart';

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
  late AnimationController _bustController;
  late Animation<Color?> _bustColorAnim;
  late AnimationController _turnController;
  late Animation<Color?> _turnColorAnim;

  // ---- 2) Game logic controller (abstracts scoring, history, rules) ----
  late final TraditionalGameController _ctrl;

  // Toggle for showing the "next player" dropdown
  bool _showNextList = false;

  // Track if animation is in progress to disable buttons
  bool _isAnimating = false;

  bool _hasShownFinishDialog = false; // ensure we only show once

  @override
  void initState() {
    super.initState();    _ctrl = TraditionalGameController(
      startingScore: widget.startingScore,
      players: widget.players,
      resumeGame: widget.gameHistory,
      checkoutRule: widget.checkoutRule,
    )..addListener(_onStateChanged);
    
    // Configure the "BUST" overlay animation (red flash)
    _bustController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Increased to 2 seconds for visibility
    );
    _bustColorAnim = ColorTween(
      begin: Colors.red, 
      end: Colors.transparent,
    ).animate(_bustController);
    
    // Add listener to track animation state
    _bustController.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        setState(() => _isAnimating = true);
      } else if (status == AnimationStatus.completed) {
        setState(() => _isAnimating = false);
      }
    });

    // Configure the "Turn Change" overlay animation (blue flash)
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Increased to 2 seconds for visibility
    );
    _turnColorAnim = ColorTween(
      begin: Colors.blue, 
      end: Colors.transparent,
    ).animate(_turnController);
    
    // Add listener to track animation state
    _turnController.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        setState(() => _isAnimating = true);
      } else if (status == AnimationStatus.completed) {
        setState(() => _isAnimating = false);
      }
    });
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
    final isTablet = size.shortestSide >= 600;
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
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isTablet = size.shortestSide >= 600;
    
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
                      _buildPlayerInfoCard(context),
                      
                      // Overlay animations
                      if (showBust || showTurnChange)
                        Positioned.fill(
                          child: _buildOverlayAnimation(showBust, showTurnChange),
                        ),
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
                  child: _buildScoreButtonsGrid(isTurnChanging, showBust, isTablet),
                ),
                
                // Miss/Undo row
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.paddingM),
                  child: _buildMissUndoButtons(isTurnChanging, showBust),
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
    final height = size.height;
    final isTablet = size.shortestSide >= 600;
    
    return Column(
      children: [
        const SizedBox(height: AppDimensions.paddingS),        // ---- 5a) Player Info Card + Overlay Stack ----
        SizedBox(
          height: height * 0.3, // 30% of screen height
          child: Stack(
            children: [
              // Core player info
              _buildPlayerInfoCard(context),
              
              // Overlay animations
              if (showBust || showTurnChange)
                Positioned.fill(
                  child: _buildOverlayAnimation(showBust, showTurnChange),
                ),
            ],
          ),
        ),

        // ---- 5b) Controls Column (Multiplier + Grid + Miss/Undo) ----
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.paddingS),

              // Multiplier buttons
              _buildMultiplierButtons(isTurnChanging, showBust),

              const SizedBox(height: AppDimensions.paddingS),

              // Score grid
              Expanded(
                child: _buildScoreButtonsGrid(isTurnChanging, showBust, isTablet),
              ),

              // Miss and Undo buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.paddingM,
                ),
                child: _buildMissUndoButtons(isTurnChanging, showBust),
              ),
            ],
          ),
        ),
      ],
    );
  }
    /// Build multiplier row buttons
  Widget _buildMultiplierButtons(bool isTurnChanging, bool showBust) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final isTablet = size.shortestSide >= 600;
    
    // Height-based scaling
    final heightScale = height / 800;
    
    // Button is disabled during animations, turn changes, or busts
    final isDisabled = _isAnimating || isTurnChanging || showBust;
    
    // Calculate button dimensions based on height
    final buttonWidth = isTablet ? 120.0 : 96.0 * heightScale;
    final buttonHeight = isTablet ? 60.0 : 52.0 * heightScale;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ctrl.multiplier == 1 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: _ctrl.multiplier == 1
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: isDisabled ? null : () => _ctrl.setMultiplier(1),
            child: Text('x1', style: theme.textTheme.titleMedium),
          ),
        ),
        SizedBox(width: AppDimensions.marginM * heightScale),
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ctrl.multiplier == 2
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: _ctrl.multiplier == 2
                  ? theme.colorScheme.onSecondary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: isDisabled ? null : () => _ctrl.setMultiplier(2),
            child: Text('x2', style: theme.textTheme.titleMedium),
          ),
        ),
        SizedBox(width: AppDimensions.marginM * heightScale),
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ctrl.multiplier == 3
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: _ctrl.multiplier == 3
                  ? theme.colorScheme.onTertiary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: isDisabled ? null : () => _ctrl.setMultiplier(3),
            child: Text('x3', style: theme.textTheme.titleMedium),
          ),
        ),
      ],
    );
  }
  
  /// Build score buttons grid for 1-20, 25, Bull
  Widget _buildScoreButtonsGrid(bool isTurnChanging, bool showBust, bool isTablet) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    
    // Screen height-based scaling
    final heightScale = height / 800; // Base scale on a height of 800
    
    // Always use a portrait layout since we've locked orientation
    final int crossAxisCount = isTablet ? 6 : 5;
      return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM * heightScale
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: isTablet ? AppDimensions.marginM : AppDimensions.marginM * heightScale,
        mainAxisSpacing: isTablet ? AppDimensions.marginM : AppDimensions.marginM * heightScale,
      ),
      itemCount: 22, // 1-20 + 25 + Bull
      itemBuilder: (context, index) {
        // Map grid position to score value
        int value;
        String label;
        
        if (index < 20) {
          // Regular numbers 1-20
          value = index + 1;
          label = value.toString();
        } else if (index == 20) {
          // 25 (outer bull)
          value = 25;
          label = '25';
        } else {
          // Bull (50)
          value = 50;
          label = 'Bull';
        }
          // Determine button size based on screen height
        final heightScale = height / 800;
        // Use smaller button sizes based on screen height
        final buttonSize = isTablet 
            ? ScoreButtonSize.medium 
            : (heightScale >= 1.0 ? ScoreButtonSize.small : ScoreButtonSize.small);
        
        // Button is disabled during animations, turn changes, or busts
        final isDisabled = _isAnimating || isTurnChanging || showBust;
        
        return ScoreButton(
          value: value,
          label: label,
          size: buttonSize,
          disabled: isDisabled,
          onPressed: () => _ctrl.score(value),
        );
      },
    );
  }
    /// Build miss and undo buttons
  Widget _buildMissUndoButtons(bool isTurnChanging, bool showBust) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final isTablet = size.shortestSide >= 600;
    
    // Height-based scaling
    final heightScale = height / 800;
    
    // Button is disabled during animations, turn changes, or busts
    final isDisabled = _isAnimating || isTurnChanging || showBust;
    
    // Calculate button dimensions based on height
    final buttonWidth = isTablet ? 150.0 : 124.0 * heightScale;
    final buttonHeight = isTablet ? 56.0 : 48.0 * heightScale;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Miss = score(0)
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: isDisabled
                ? null
                : () => _ctrl.score(0),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Miss'),
          ),
        ),

        SizedBox(width: AppDimensions.marginM * heightScale),

        // Undo = undoLastThrow()
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            ),
            onPressed: isDisabled
                ? null
                : _ctrl.undoLastThrow,
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
        ),
      ],
    );
  }
  
  /// Build overlay for animations (bust or turn change)
  Widget _buildOverlayAnimation(bool showBust, bool showTurnChange) {
    return AnimatedBuilder(
      // Listen to both controllers so color.value updates
      animation: Listenable.merge([_bustController, _turnController]),
      builder: (_, __) {
        // Choose red or blue flash color
        final bgColor = showBust
            ? _bustColorAnim.value!
            : _turnColorAnim.value!;
              return OverlayAnimation(
          showBust: showBust,
          showTurnChange: showTurnChange,
          bgColor: bgColor,
          lastTurnPoints: _ctrl.lastTurnPoints(),
          lastTurnLabels: _ctrl.lastTurnLabels(),
          nextPlayerName: _ctrl.activePlayers[_ctrl.activeNextIndex],
          size: OverlaySize.large,
        );
      },
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
      top: kToolbarHeight,
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
                  color: isUpcoming
                      ? theme.colorScheme.secondary
                      : isCurrent
                          ? theme.colorScheme.primary
                          : null,
                ),
              ),
              trailing: Text(
                '$pts',
                style: theme.textTheme.titleMedium,
              ),
              onTap: () => setState(() => _showNextList = false),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ---- 6) Helper: Player info card (score + darts + finish hint) ----
  Widget _buildPlayerInfoCard(BuildContext context) {    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final isTablet = size.shortestSide >= 600;
    final isLandscape = width > height;
    final dartIconSize = isTablet ? 40.0 : 32.0;
    
    final act = _ctrl.activePlayers;
    final actScores = act.map((p) => _ctrl.scoreFor(p)).toList();
    final curIdx = _ctrl.activeCurrentIndex;

    return Center(
      child: Container(
        width: isLandscape 
            ? double.infinity
            : width * 0.9,
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
          horizontal: isTablet ? AppDimensions.paddingXL : AppDimensions.paddingL,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player name (shortened if too long)
            Text(
              shortenName(act[curIdx], maxLength: 12),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppDimensions.marginS),            // Current score - Scale based on screen height
            Text(
              '${actScores[curIdx]}',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 72.0 : 56.0 * (height / 800),
              ),
            ),

            const SizedBox(height: AppDimensions.marginM),

            // Dart icons for this turn
            _buildDartIcons(context, iconSize: dartIconSize),

            const SizedBox(height: AppDimensions.marginM),

            // Hint for possible finish
            _buildPossibleFinish(fontSize: isTablet ? 18.0 : 14.0),
          ],
        ),
      ),
    );
  }

  // ---- 7) Helper: Render last-turn dart icons + remaining blank slots ----
  Widget _buildDartIcons(BuildContext context, {double iconSize = 32}) {
    final theme = Theme.of(context);
    final name = _ctrl.players[_ctrl.currentPlayer];
    final used = (_ctrl.dartsThrown).clamp(0, 3);
    final remaining = 3 - used;

    // Grab only this player's throws, then take the last [used]
    final allThrows = _ctrl.currentGame.throws
        .where((t) => t.player == name)
        .toList();
    final recent = allThrows.length >= used
        ? allThrows.sublist(allThrows.length - used)
        : allThrows;

    final activeTextStyle = TextStyle(
      fontSize: iconSize * 0.8,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
    );

    // Get icon color from theme
    final iconColor = theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Show score labels for used darts
        for (var t in recent) ...[
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 4 * (iconSize / 32)),
            child: Text(
              t.value == 0
                  ? 'M'
                  : t.value == 50
                      ? 'BULL'
                      : t.multiplier == 2
                          ? 'D${t.value}'
                          : t.multiplier == 3
                              ? 'T${t.value}'
                              : '${t.value}',
              style: activeTextStyle,
            ),
          ),
        ],

        // Show blank dart icons for remaining throws
        for (int i = 0; i < remaining; i++) ...[
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 4 * (iconSize / 32)),
            child: SvgPicture.asset(
              'assets/icons/dart-icon.svg',
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                  iconColor, BlendMode.srcIn),
            ),
          ),
        ],
      ],
    );
  }

  // ---- 8) Helper: Possible finish hint based on `possibleFinishes` map ----
  Widget _buildPossibleFinish({double fontSize = 14}) {
    final theme = Theme.of(context);
    final score = _ctrl.scores[_ctrl.currentPlayer];
    final dartsLeft = 3 - _ctrl.dartsThrown;
    final options = bestCheckouts(
      score,
      dartsLeft,
      _ctrl.checkoutRule,
      limit: 3, // top 3
    );

    if (options.isNotEmpty) {
      // pick the very best one, or show all 3
      final best = options.first;
      return Text(
        'Best finish: ${best.join(" ")}',
        style: TextStyle(
          fontSize: fontSize,
          color: theme.colorScheme.primary,
        ),
      );
    }

    // Otherwise no legal finish
    return Text(
      'No finish possible',
      style: TextStyle(
        fontSize: fontSize,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }
}