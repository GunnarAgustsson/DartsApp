
import 'package:dars_scoring_app/models/donkey_game.dart';
import 'package:dars_scoring_app/models/app_enums.dart';
import 'package:dars_scoring_app/services/donkey_game_service.dart';
import 'package:dars_scoring_app/theme/index.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/widgets/game_overlay_animation.dart';
import 'package:dars_scoring_app/widgets/scoring_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Donkey game screen - HORSE-style darts game
/// Players take turns trying to beat the previous score
/// Failed attempts earn letters (D-O-N-K-E-Y)
/// First player to spell DONKEY loses
class DonkeyGameScreen extends StatefulWidget {

  const DonkeyGameScreen({
    super.key,
    required this.players,
    this.gameHistory,
    this.randomOrder = false,
    this.variant = DonkeyVariant.oneDart,
  });
  final List<String> players;
  final DonkeyGameHistory? gameHistory;
  final bool randomOrder;
  final DonkeyVariant variant;

  @override
  State<DonkeyGameScreen> createState() => _DonkeyGameScreenState();
}

class _DonkeyGameScreenState extends State<DonkeyGameScreen>
    with TickerProviderStateMixin {
  // Game logic controller
  late final DonkeyGameController _ctrl;
  // Toggle for showing player status
  bool _showPlayerStatus = false;
  bool _hasShownFinishDialog = false;

  @override
  void initState() {
    super.initState();
    // Initialize donkey game controller
    _ctrl = DonkeyGameController(
      players: widget.players,
      resumeGame: widget.gameHistory,
      randomOrder: widget.randomOrder,
      variant: widget.variant,
    )..addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Called whenever the game state changes
  void _onStateChanged() {
    setState(() {});

    // Show finish dialog if game has ended
    if (_ctrl.showPlayerFinished && !_hasShownFinishDialog) {
      _hasShownFinishDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFinishDialog(_ctrl.lastFinisher!);
      });
    }
  }

  /// Get the next player name for display
  String get _nextPlayerName {
    if (_ctrl.players.isEmpty) return '';
    final nextIndex = (_ctrl.currentPlayer + 1) % _ctrl.players.length;
    return _ctrl.players[nextIndex];
  }

  Future<void> _showFinishDialog(String winner) {
    final theme = Theme.of(context);
    
    return showDialog(
      context: context,
      barrierDismissible: false,      builder: (_) => AlertDialog(
        title: Text('🎉 Congratulations!', style: theme.textTheme.titleLarge),
        content: Text(
          '$winner wins! All other players are now Donkeys! 🐴',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _ctrl.clearPlayerFinishedFlag();
              _hasShownFinishDialog = false;
            },
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Determine new player order based on randomOrder setting
              List<String> newPlayerOrder;
              if (widget.randomOrder) {
                newPlayerOrder = List.from(widget.players);
                newPlayerOrder.shuffle();
              } else {
                newPlayerOrder = List.from(widget.players);
                if (newPlayerOrder.isNotEmpty) {
                  final firstPlayer = newPlayerOrder.removeAt(0);
                  newPlayerOrder.add(firstPlayer);
                }
              }

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => DonkeyGameScreen(
                    players: newPlayerOrder,
                    randomOrder: widget.randomOrder,
                    variant: widget.variant,
                  ),
                ),
              );
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Main Menu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTurnChange = _ctrl.showTurnChange;
    final isTurnChanging = _ctrl.isTurnChanging;
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final isLandscape = width > height;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: AppDimensions.elevationS,
        leading: IconButton(
          icon: Icon(
            Icons.home,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: Text(
          'Donkey (${widget.variant.title})',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => setState(() => _showPlayerStatus = !_showPlayerStatus),
            child: Padding(
              padding: const EdgeInsets.only(right: AppDimensions.paddingM),
              child: Center(
                child: Text(
                  'Players',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: isLandscape 
                ? _buildLandscapeLayout(context, showTurnChange, isTurnChanging)
                : _buildPortraitLayout(context, showTurnChange, isTurnChanging),
          ),
          
          // Overlay animation covering entire screen except header
          _buildOverlayAnimation(showTurnChange, _nextPlayerName),
          
          // Player status dropdown overlay
          if (_showPlayerStatus)
            _buildPlayerStatusDropdown(),
        ],
      ),
    );
  }

  /// Build landscape layout
  Widget _buildLandscapeLayout(
    BuildContext context,
    bool showTurnChange,
    bool isTurnChanging,
  ) {    final theme = Theme.of(context);
    final isDisabled = isTurnChanging || showTurnChange;

    return Row(
      children: [
        // Left side - Current player info and target
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: _buildCurrentPlayerCard(context),
          ),
        ),
        
        // Vertical divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),        
        // Right side - Controls
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              children: [
                // Dartboard sections grid with integrated multipliers and actions
                Expanded(
                  child: _buildDartboardGrid(isDisabled),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build portrait layout
  Widget _buildPortraitLayout(
    BuildContext context,
    bool showTurnChange,
    bool isTurnChanging,
  ) {
    final isDisabled = isTurnChanging || showTurnChange;

    return Column(
      children: [
        // Top section - Current player and target
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: _buildCurrentPlayerCard(context),
          ),
        ),

        // Controls Area
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: Column(
              children: [
                // Dartboard sections grid with integrated multipliers and actions
                Expanded(
                  child: _buildDartboardGrid(isDisabled),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  /// Build current player info card
  Widget _buildCurrentPlayerCard(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    // Safety check for game over state
    if (_ctrl.players.isEmpty || _ctrl.currentPlayer >= _ctrl.players.length) {
      return const SizedBox.shrink();
    }
    
    final currentPlayerName = _ctrl.players[_ctrl.currentPlayer];
    final currentPlayerState = _ctrl.getPlayerState(currentPlayerName);

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
              color: theme.colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Player name
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Text(
                  shortenName(currentPlayerName, maxLength: 15),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.marginS),

            // Current target to beat
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(
                    'Target to Beat',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      _ctrl.currentTarget == 0 ? 'Set Target' : _ctrl.currentTarget.toString(),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (_ctrl.targetSetBy.isNotEmpty)
                    Text(
                      'Set by ${shortenName(_ctrl.targetSetBy, maxLength: 10)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: AppDimensions.marginS),

            // Current turn score
            if (_ctrl.currentTurnScore > 0)
              Expanded(
                flex: 1,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    'Current: ${_ctrl.currentTurnScore}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _ctrl.currentTurnScore > _ctrl.currentTarget 
                          ? Colors.green 
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

            // Player letters
            Expanded(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  currentPlayerState.letters.isEmpty 
                      ? 'No Letters' 
                      : _ctrl.getDisplayLetters(currentPlayerName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: currentPlayerState.letters.isEmpty 
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : Colors.red,
                  ),
                ),
              ),
            ),

            // Darts left icons (only for 3-dart mode)
            if (_ctrl.maxDartsPerTurn > 1)
              Expanded(
                flex: 1,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_ctrl.maxDartsPerTurn, (index) {
                      final isThrown = index < _ctrl.dartsThrown;
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
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                    : theme.colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                            if (isThrown && label != null)
                              Text(
                                label,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
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

  /// Build dartboard grid (always shows numbers 1-20 in sequential order)
  Widget _buildDartboardGrid(bool isDisabled) {
    return ScoringButtons(
      config: ScoringButtonsConfig(
        showMultipliers: true,
        show25Button: true,
        showBullButton: true,
        showMissButton: true,
        showUndoButton: true,
        disabled: isDisabled,
      ),
      onScore: (score, label) {
        if (score == 0) {
          _ctrl.scoreMiss();
        } else {
          _ctrl.score(score, label);
        }
      },
      onUndo: _ctrl.undoLastThrow,
    );
  }
  /// Build overlay for turn change animation
  Widget _buildOverlayAnimation(bool showTurnChange, String nextPlayerName) {
    final showLetterReceived = _ctrl.showLetterReceived;
    final showPlayerEliminated = _ctrl.showPlayerEliminated;
    
    GameOverlayType overlayType;
    if (showLetterReceived) {
      overlayType = GameOverlayType.letterReceived;
    } else if (showPlayerEliminated) {
      overlayType = GameOverlayType.playerEliminated;
    } else {
      overlayType = GameOverlayType.turnChange;
    }

    return GameOverlayAnimation(
      overlayType: overlayType,
      isVisible: showTurnChange || showLetterReceived || showPlayerEliminated,
      playerName: _ctrl.letterReceivedPlayer ?? _ctrl.eliminatedPlayer ?? '',
      nextPlayerName: showTurnChange ? _ctrl.players[_ctrl.currentPlayer] : nextPlayerName,
      lastTurnPoints: showTurnChange ? _ctrl.lastTurnScore.toString() : _ctrl.currentTurnScore.toString(),
      lastTurnLabels: _ctrl.currentTurnDartLabels.join(', '),
      letterReceivedLetters: _ctrl.letterReceivedLetters ?? '',
      animationDuration: _ctrl.animationDuration,
      onAnimationComplete: () {
        if (showLetterReceived) {
          _ctrl.clearLetterReceivedFlag();
        } else if (showPlayerEliminated) {
          _ctrl.clearPlayerEliminatedFlag();
        }
      },
      onTapToClose: () {
        if (showLetterReceived) {
          _ctrl.clearLetterReceivedFlag();
        } else if (showPlayerEliminated) {
          _ctrl.clearPlayerEliminatedFlag();
        }
      },
    );
  }

  /// Build player status dropdown overlay
  Widget _buildPlayerStatusDropdown() {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Positioned(
      top: 0,
      left: AppDimensions.paddingM,
      right: AppDimensions.paddingM,
      child: Card(
        elevation: AppDimensions.elevationM,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusM),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Player',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Letters',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Status',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Player rows
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _ctrl.gameHistory.originalPlayers.map((playerName) {
                      final playerState = _ctrl.getPlayerState(playerName);
                      final isCurrentPlayer = _ctrl.players[_ctrl.currentPlayer] == playerName;
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.paddingXS,
                          horizontal: AppDimensions.paddingS,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentPlayer 
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : null,
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Player name
                            Expanded(
                              flex: 3,
                              child: Text(
                                shortenName(playerName, maxLength: 12),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isCurrentPlayer ? FontWeight.bold : null,
                                  color: isCurrentPlayer 
                                      ? theme.colorScheme.primary 
                                      : null,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Letters
                            Expanded(
                              flex: 2,
                              child: Text(
                                playerState.letters.isEmpty 
                                    ? '-' 
                                    : _ctrl.getDisplayLetters(playerName),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: playerState.letters.isEmpty 
                                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Status
                            Expanded(
                              flex: 2,
                              child: Text(
                                playerState.isEliminated 
                                    ? 'OUT' 
                                    : isCurrentPlayer 
                                        ? 'TURN' 
                                        : 'ACTIVE',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: playerState.isEliminated 
                                      ? Colors.red
                                      : isCurrentPlayer 
                                          ? theme.colorScheme.primary
                                          : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              // Close button
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                child: TextButton(
                  onPressed: () => setState(() => _showPlayerStatus = false),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
