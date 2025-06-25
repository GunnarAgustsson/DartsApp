import 'dart:math';

import 'package:dars_scoring_app/models/donkey_game.dart';
import 'package:dars_scoring_app/models/app_enums.dart';
import 'package:dars_scoring_app/services/donkey_game_service.dart';
import 'package:dars_scoring_app/theme/app_dimensions.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/widgets/overlay_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/score_button.dart';

/// Donkey game screen - HORSE-style darts game
/// Players take turns trying to beat the previous score
/// Failed attempts earn letters (D-O-N-K-E-Y)
/// First player to spell DONKEY loses
class DonkeyGameScreen extends StatefulWidget {
  final List<String> players;
  final DonkeyGameHistory? gameHistory;
  final bool randomOrder;
  final DonkeyVariant variant;

  const DonkeyGameScreen({
    super.key,
    required this.players,
    this.gameHistory,
    this.randomOrder = false,
    this.variant = DonkeyVariant.oneDart,
  });

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
            child: Text('Continue', style: theme.textTheme.labelMedium),
            onPressed: () {
              Navigator.of(context).pop();
              _ctrl.clearPlayerFinishedFlag();
              _hasShownFinishDialog = false;
            },
          ),
          TextButton(
            child: Text('Play Again', style: theme.textTheme.labelMedium),
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
    final nextPlayerName = _ctrl.players.isNotEmpty && _ctrl.currentPlayer < _ctrl.players.length
        ? _ctrl.players[(_ctrl.currentPlayer + 1) % _ctrl.players.length]
        : '';

    return Row(
      children: [
        // Left side - Current player info and target
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Stack(
              children: [
                _buildCurrentPlayerCard(context),
                _buildOverlayAnimation(showTurnChange, nextPlayerName),
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
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              children: [
                // Multiplier buttons (for both 1-dart and 3-dart modes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                  child: _buildMultiplierButtons(isTurnChanging),
                ),
                
                // Dartboard sections grid
                Expanded(
                  flex: 4,
                  child: _buildDartboardGrid(isDisabled),
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

  /// Build portrait layout
  Widget _buildPortraitLayout(
    BuildContext context,
    bool showTurnChange,
    bool isTurnChanging,
  ) {    final size = MediaQuery.of(context).size;
    final isDisabled = isTurnChanging || showTurnChange;
    final nextPlayerName = _ctrl.players.isNotEmpty && _ctrl.currentPlayer < _ctrl.players.length
        ? _ctrl.players[(_ctrl.currentPlayer + 1) % _ctrl.players.length]
        : '';

    return Column(
      children: [
        // Top section - Current player and target
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Stack(
              children: [
                _buildCurrentPlayerCard(context),
                _buildOverlayAnimation(showTurnChange, nextPlayerName),
              ],
            ),
          ),
        ),

        // Controls Area
        Expanded(
          flex: 4,
          child: Padding(            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: Column(
              children: [
                // Multiplier Buttons (for both 1-dart and 3-dart modes)
                SizedBox(
                  height: size.height * 0.07,
                  child: _buildMultiplierButtons(isTurnChanging),
                ),
                const SizedBox(height: AppDimensions.marginM),

                // Dartboard sections grid
                Expanded(
                  flex: 4,
                  child: _buildDartboardGrid(isDisabled),
                ),
                const SizedBox(height: AppDimensions.marginM),

                // Special Actions (Miss, Undo)
                _buildSpecialActions(isDisabled),
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
              color: theme.colorScheme.shadow.withOpacity(0.1),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                        ? theme.colorScheme.onSurface.withOpacity(0.5)
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
                                    ? theme.colorScheme.onSurface.withOpacity(0.3)
                                    : theme.colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                            if (isThrown && label != null)
                              Text(
                                label,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
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

  /// Build dartboard grid (standard dartboard numbers)
  Widget _buildDartboardGrid(bool isDisabled) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(builder: (context, constraints) {
      const crossAxisCount = 4;
      const mainAxisCount = 6; // 6 rows to fit all numbers + bull
      const hSpacing = AppDimensions.marginS;
      const vSpacing = AppDimensions.marginS;

      final buttonWidth = (constraints.maxWidth - (crossAxisCount - 1) * hSpacing) / crossAxisCount;
      final buttonHeight = (constraints.maxHeight - (mainAxisCount - 1) * vSpacing) / mainAxisCount;
      final side = min(buttonWidth, buttonHeight);
      final numberButtonSize = Size(side, side);      // Numbers in numerical order (1-20)
      final numbers = [
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
        13, 14, 15, 16,
        17, 18, 19, 20,
      ];

      List<Widget> rows = [];
      
      // Create 5 rows of 4 numbers each
      for (int row = 0; row < 5; row++) {
        List<Widget> rowButtons = [];
        
        for (int col = 0; col < 4; col++) {
          final index = row * 4 + col;
          final value = numbers[index];
          
          rowButtons.add(
            Expanded(
              child: ScoreButton(
                value: value,
                onPressed: () => _ctrl.score(value),
                disabled: isDisabled || _ctrl.isTurnComplete,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.primary,
                size: ScoreButtonSize.custom,
                customSize: numberButtonSize,
              ),
            ),
          );
          
          if (col < 3) {
            rowButtons.add(const SizedBox(width: hSpacing));
          }
        }
        
        rows.add(Expanded(child: Row(children: rowButtons)));
        if (row < 4) {
          rows.add(const SizedBox(height: vSpacing));
        }
      }

      // Add Bull button row (centered)
      List<Widget> bullRow = [
        const Spacer(),
        Expanded(
          child: ScoreButton(
            value: 25,
            label: 'Bull',
            onPressed: () => _ctrl.score(25),
            disabled: isDisabled || _ctrl.isTurnComplete,
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
            foregroundColor: theme.colorScheme.secondary,
            size: ScoreButtonSize.custom,
            customSize: numberButtonSize,
          ),
        ),
        const Spacer(),
      ];
      
      rows.add(const SizedBox(height: vSpacing));
      rows.add(Expanded(child: Row(children: bullRow)));

      return Column(children: rows);
    });
  }
  /// Build multiplier row buttons (for both 1-dart and 3-dart modes)
  Widget _buildMultiplierButtons(bool isTurnChanging) {
    final theme = Theme.of(context);
    final isDisabled = isTurnChanging;

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
                        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                      ),
                    ),
                    onPressed: isDisabled ? null : () => _ctrl.setMultiplier(1),
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
                      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    ),
                  ),
                  onPressed: isDisabled ? null : () => _ctrl.setMultiplier(multiplier),
                  child: Text('x$multiplier', style: const TextStyle(fontSize: 18)),
                ),
        ),
      );
    }

    return Row(
      children: [
        const Spacer(),
        buildButton(2, theme.colorScheme.secondary, theme.colorScheme.secondaryContainer),
        const SizedBox(width: AppDimensions.marginS),
        buildButton(3, theme.colorScheme.tertiary, theme.colorScheme.tertiaryContainer),
        const Spacer(),
      ],
    );
  }

  /// Build special action buttons (Miss, Undo)
  Widget _buildSpecialActions(bool isDisabled) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    final buttonHeight = isLandscape 
        ? max(40.0, size.height * 0.075) 
        : max(45.0, size.height * 0.055);    return Row(
      children: [
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
              onPressed: isDisabled || _ctrl.isTurnComplete ? null : () => _ctrl.scoreMiss(),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text(
                'Miss',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
              onPressed: (isDisabled || _ctrl.dartsThrown == 0) ? null : _ctrl.undoLastThrow,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text(
                'Undo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        
        // End Turn Button (only for 3-dart mode)
        if (_ctrl.variant == DonkeyVariant.threeDart) ...[
          const SizedBox(width: AppDimensions.marginS),
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: const StadiumBorder(),
                ),
                onPressed: (isDisabled || _ctrl.dartsThrown == 0 || _ctrl.isTurnComplete) ? null : _ctrl.endTurn,
                icon: const Icon(Icons.check, size: 18),
                label: const Text(
                  'End Turn',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }  /// Build overlay for turn change animation
  Widget _buildOverlayAnimation(bool showTurnChange, String nextPlayerName) {
    final showLetterReceived = _ctrl.showLetterReceived;
    final showPlayerEliminated = _ctrl.showPlayerEliminated;
    
    return Visibility(
      visible: showTurnChange || showLetterReceived || showPlayerEliminated,
      child: GestureDetector(
        onTap: () {
          if (showLetterReceived) {
            _ctrl.clearLetterReceivedFlag();
          } else if (showPlayerEliminated) {
            _ctrl.clearPlayerEliminatedFlag();
          }
        },
        child: AnimatedOpacity(
          opacity: (showTurnChange || showLetterReceived || showPlayerEliminated) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: OverlayAnimation(
            showBust: false,
            showTurnChange: showTurnChange,
            showLetterReceived: showLetterReceived,
            showPlayerEliminated: showPlayerEliminated,
            lastTurnPoints: _ctrl.currentTurnScore.toString(),
            lastTurnLabels: _ctrl.currentTurnDartLabels.join(', '),
            nextPlayerName: nextPlayerName,
            letterReceivedPlayer: _ctrl.letterReceivedPlayer ?? _ctrl.eliminatedPlayer ?? '',
            letterReceivedLetters: _ctrl.letterReceivedLetters ?? '',
            animationDuration: _ctrl.animationDuration,
          ),
        ),
      ),
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
                  color: theme.colorScheme.primary.withOpacity(0.1),
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
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : null,
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.1),
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
                                      ? theme.colorScheme.onSurface.withOpacity(0.5)
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
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
