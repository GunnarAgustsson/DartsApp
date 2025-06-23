import 'dart:math';

import 'package:dars_scoring_app/models/cricket_game.dart';
import 'package:dars_scoring_app/services/cricket_game_service.dart';
import 'package:dars_scoring_app/theme/app_dimensions.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'package:dars_scoring_app/widgets/overlay_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/score_button.dart';

/// Cricket game screen - follows traditional cricket darts rules
/// Players must close numbers 20, 19, 18, 17, 16, 15, and Bull
/// To close a number, hit it 3 times (any combination of singles, doubles, triples)
/// Once closed, additional hits score points (if opponents haven't closed it yet)
/// Win by closing all numbers and having highest score
class CricketGameScreen extends StatefulWidget {
  final List<String> players;
  final CricketGameHistory? gameHistory;
  final bool randomOrder;

  const CricketGameScreen({
    super.key,
    required this.players,
    this.gameHistory,
    this.randomOrder = false,
  });

  @override
  State<CricketGameScreen> createState() => _CricketGameScreenState();
}

class _CricketGameScreenState extends State<CricketGameScreen>
    with TickerProviderStateMixin {
  // Game logic controller
  late final CricketGameController _ctrl;
  // Toggle for showing the scoreboard dropdown
  bool _showScoreboardDropdown = false;
  bool _hasShownFinishDialog = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize cricket game controller
    _ctrl = CricketGameController(
      players: widget.players,
      resumeGame: widget.gameHistory,
      randomOrder: widget.randomOrder,
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

    // Show finish dialog if player has won
    if (_ctrl.showPlayerFinished && !_hasShownFinishDialog) {
      _hasShownFinishDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFinishDialog(_ctrl.lastFinisher!);
      });
    }
  }

  Future<void> _showFinishDialog(String finisher) {
    final theme = Theme.of(context);
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Congratulations, $finisher!', style: theme.textTheme.titleLarge),
        content: Text(
          '$finisher has won the Cricket game!',
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
                  builder: (_) => CricketGameScreen(
                    players: newPlayerOrder,
                    randomOrder: widget.randomOrder,
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
          'Cricket',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),        actions: [
          GestureDetector(
            onTap: () => setState(() => _showScoreboardDropdown = !_showScoreboardDropdown),
            child: Padding(
              padding: const EdgeInsets.only(right: AppDimensions.paddingM),
              child: Center(
                child: Text(
                  'Scoreboard',
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
            // Scoreboard dropdown overlay
          if (_showScoreboardDropdown)
            _buildScoreboardDropdown(),
        ],
      ),
    );
  }
  /// Build landscape layout
  Widget _buildLandscapeLayout(
    BuildContext context,
    bool showTurnChange,
    bool isTurnChanging,
  ) {
    final theme = Theme.of(context);
    final isDisabled = isTurnChanging || showTurnChange;
    final nextPlayerName = _ctrl.players[(_ctrl.currentPlayer + 1) % _ctrl.players.length];

    return Row(
      children: [
        // Left side - Current player info (expanded to use freed space)
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
        
        // Right side - Controls (expanded to use freed space)
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              children: [
                // Multiplier buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                  child: _buildMultiplierButtons(isTurnChanging),
                ),
                
                // Cricket numbers grid (takes more space)
                Expanded(
                  flex: 4,
                  child: _buildCricketNumbersGrid(isDisabled),
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
  ) {
    final size = MediaQuery.of(context).size;
    final isDisabled = isTurnChanging || showTurnChange;
    final nextPlayerName = _ctrl.players[(_ctrl.currentPlayer + 1) % _ctrl.players.length];

    return Column(
      children: [
        // Top section - Current player (expanded to use freed space)
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

        // Controls Area (expanded to use freed space)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: Column(
              children: [
                // Multiplier Buttons
                SizedBox(
                  height: size.height * 0.07,
                  child: _buildMultiplierButtons(isTurnChanging),
                ),
                const SizedBox(height: AppDimensions.marginM),

                // Cricket numbers grid (takes more space)
                Expanded(
                  flex: 4,
                  child: _buildCricketNumbersGrid(isDisabled),
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

            // Current score
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  currentPlayerState.score.toString(),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: AppDimensions.marginS),

            // Darts left icons
            Expanded(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
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
                                fontSize: 10,
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
  /// Get display widget for hits using icons and colors
  Widget _getHitsDisplayWidget(int hits, bool isCurrentPlayer, ThemeData theme) {
    if (hits == 0) return const SizedBox.shrink();
    
    Color getColor() {
      if (hits >= 3) return Colors.green;
      if (hits == 2) return Colors.orange;
      return Colors.red;
    }
    
    List<Widget> hitIcons = [];
    for (int i = 0; i < min(hits, 3); i++) {
      hitIcons.add(
        Icon(
          hits >= 3 ? Icons.close : Icons.remove,
          size: 12,
          color: getColor(),
        )
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: hitIcons,
    );
  }  /// Build cricket numbers grid (15-20, Bull)
  Widget _buildCricketNumbersGrid(bool isDisabled) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(builder: (context, constraints) {
      const crossAxisCount = 2;
      const mainAxisCount = 4; // 4 rows (20,19 / 18,17 / 16,15 / Bull)
      const hSpacing = AppDimensions.marginS;
      const vSpacing = AppDimensions.marginS;

      final buttonWidth = (constraints.maxWidth - (crossAxisCount - 1) * hSpacing) / crossAxisCount;
      final buttonHeight = (constraints.maxHeight - (mainAxisCount - 1) * vSpacing) / mainAxisCount;
      final side = min(buttonWidth, buttonHeight);
      final numberButtonSize = Size(side, side);

      // Cricket numbers: 20, 19, 18, 17, 16, 15, Bull
      final numbers = [20, 19, 18, 17, 16, 15, 25];
      
      List<Widget> rows = [];
      for (int row = 0; row < 4; row++) {
        List<Widget> rowButtons = [];
        
        if (row < 3) {
          // Regular number rows (20,19 / 18,17 / 16,15)
          final startIdx = row * 2;          for (int col = 0; col < 2; col++) {
            final numIdx = startIdx + col;
            if (numIdx < numbers.length - 1) { // Exclude bull for now
              final value = numbers[numIdx];
              final canScore = _ctrl.canCurrentPlayerScoreOn(value);
              final currentPlayerState = _ctrl.getPlayerState(_ctrl.players[_ctrl.currentPlayer]);
              final hits = currentPlayerState.hits[value]!;
                // Color coding: start as inverted primary, then red, yellow, primary (closed)
              Color getBackgroundColor() {
                if (hits >= 3) return Colors.green.withOpacity(0.7); // closed - green
                if (!canScore) return theme.colorScheme.outline.withOpacity(0.3); // disabled
                if (hits == 0) return theme.colorScheme.primary.withOpacity(0.1); // inverted primary
                if (hits == 1) return Colors.red.withOpacity(0.7);
                if (hits == 2) return Colors.orange.withOpacity(0.7);
                return theme.colorScheme.primary.withOpacity(0.7);
              }
              
              Color getForegroundColor() {
                if (hits >= 3) return Colors.white; // closed
                if (!canScore) return theme.colorScheme.outline;
                if (hits == 0) return theme.colorScheme.primary;
                return Colors.white;
              }
              
              rowButtons.add(
                Expanded(
                  child: ScoreButton(
                    value: value,
                    onPressed: canScore ? () => _ctrl.score(value) : () {}, // Empty callback for disabled
                    disabled: isDisabled || !canScore,
                    backgroundColor: getBackgroundColor(),
                    foregroundColor: getForegroundColor(),
                    size: ScoreButtonSize.custom,
                    customSize: numberButtonSize,
                  ),
                ),
              );
              if (col < 1) {
                rowButtons.add(const SizedBox(width: hSpacing));
              }
            }
          }        } else {
          // Bull row (center it)
          final value = 25;
          final canScore = _ctrl.canCurrentPlayerScoreOn(value);
          final currentPlayerState = _ctrl.getPlayerState(_ctrl.players[_ctrl.currentPlayer]);
          final hits = currentPlayerState.hits[value]!;
            // Color coding for Bull
          Color getBackgroundColor() {
            if (hits >= 3) return Colors.green.withOpacity(0.7); // closed - green
            if (!canScore) return theme.colorScheme.outline.withOpacity(0.3); // disabled
            if (hits == 0) return theme.colorScheme.primary.withOpacity(0.1); // inverted primary
            if (hits == 1) return Colors.red.withOpacity(0.7);
            if (hits == 2) return Colors.orange.withOpacity(0.7);
            return theme.colorScheme.primary.withOpacity(0.7);
          }
          
          Color getForegroundColor() {
            if (hits >= 3) return Colors.white; // closed
            if (!canScore) return theme.colorScheme.outline;
            if (hits == 0) return theme.colorScheme.primary;
            return Colors.white;
          }
          
          rowButtons.add(const Spacer());
          rowButtons.add(
            Expanded(
              child: ScoreButton(
                value: 25,
                label: 'Bull',
                onPressed: canScore ? () => _ctrl.score(25) : () {},
                disabled: isDisabled || !canScore,
                backgroundColor: getBackgroundColor(),
                foregroundColor: getForegroundColor(),
                size: ScoreButtonSize.custom,
                customSize: numberButtonSize,
              ),
            ),
          );
          rowButtons.add(const Spacer());
        }
        
        rows.add(Expanded(child: Row(children: rowButtons)));
        if (row < 3) {
          rows.add(const SizedBox(height: vSpacing));
        }
      }

      return Column(children: rows);
    });
  }

  /// Build multiplier row buttons
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
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    final buttonHeight = isLandscape 
        ? max(40.0, size.height * 0.075) 
        : max(45.0, size.height * 0.055);
    
    final baseFontSize = isLandscape 
        ? min(14.0, size.width * 0.018) 
        : min(16.0, size.width * 0.035);
    final fontSize = baseFontSize / max(1.0, textScaleFactor * 0.8);
    
    final baseIconSize = isLandscape 
        ? min(16.0, size.width * 0.02) 
        : min(18.0, size.width * 0.04);
    final iconSize = baseIconSize / max(1.0, textScaleFactor * 0.8);
    
    final spacing = isLandscape || textScaleFactor < 1.0
        ? AppDimensions.marginXS / 2
        : AppDimensions.marginXS;

    return Row(
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
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 6.0 : 8.0,
                  vertical: 4.0,
                ),
              ),
              onPressed: isDisabled ? null : () => _ctrl.scoreMiss(),
              icon: Icon(
                Icons.cancel_outlined, 
                size: iconSize,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Miss',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize * 0.9,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: spacing),
        
        // Undo Button
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error, width: 2),
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 6.0 : 8.0,
                  vertical: 4.0,
                ),
              ),
              onPressed: isDisabled ? null : _ctrl.undoLastThrow,
              icon: Icon(
                Icons.undo, 
                size: iconSize,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Undo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize * 0.9,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build overlay for turn change animation
  Widget _buildOverlayAnimation(bool showTurnChange, String nextPlayerName) {
    return Visibility(
      visible: showTurnChange,
      child: AnimatedOpacity(
        opacity: showTurnChange ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: OverlayAnimation(
          showBust: false,
          showTurnChange: showTurnChange,
          lastTurnPoints: '', // Cricket doesn't show points like traditional
          lastTurnLabels: _ctrl.lastTurnLabels(),
          nextPlayerName: nextPlayerName,
        ),
      ),
    );
  }
    /// Build scoreboard dropdown overlay
  Widget _buildScoreboardDropdown() {
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
                      flex: 2,
                      child: Text(
                        'Number',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ..._ctrl.players.map((player) => Expanded(
                      flex: 2,
                      child: Text(
                        shortenName(player, maxLength: 8),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _ctrl.players[_ctrl.currentPlayer] == player
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                ),
              ),
              
              // Numbers rows
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: CricketGameController.cricketNumbers.map((number) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.paddingXS,
                          horizontal: AppDimensions.paddingS,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Number column
                            Expanded(
                              flex: 2,
                              child: Text(
                                number == 25 ? 'Bull' : number.toString(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _ctrl.isNumberClosedForAll(number)
                                      ? theme.colorScheme.outline
                                      : null,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                              // Player columns
                            ..._ctrl.players.map((player) {
                              final playerState = _ctrl.getPlayerState(player);
                              final hits = playerState.hits[number]!;
                              final isCurrentPlayer = _ctrl.players[_ctrl.currentPlayer] == player;
                              return Expanded(
                                flex: 2,
                                child: _getHitsDisplayWidget(hits, isCurrentPlayer, theme),
                              );
                            }),
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
                  onPressed: () => setState(() => _showScoreboardDropdown = false),
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
