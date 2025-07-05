import 'package:flutter/material.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/theme/index.dart';

/// Defines different size variants for the overlay
enum OverlaySize { small, medium, large }

/// A widget that shows animated overlays for bust and turn changes
class OverlayAnimation extends StatelessWidget {
  /// Whether to show the bust overlay
  final bool showBust;
    /// Whether to show the turn change overlay
  final bool showTurnChange;
    /// Whether to show the letter received overlay
  final bool showLetterReceived;
  
  /// Whether to show the player eliminated overlay
  final bool showPlayerEliminated;
  
  /// Background color for the overlay
  final Color? bgColor;
  
  /// Points scored in the last turn
  final String lastTurnPoints;
  
  /// Labels for darts thrown in the last turn
  final String lastTurnLabels;
  
  /// Name of the next player
  final String nextPlayerName;

  /// Player who received a letter
  final String letterReceivedPlayer;
  
  /// Letters the player now has
  final String letterReceivedLetters;

  /// Size variant for the overlay
  final OverlaySize size;

  /// Animation duration for this overlay
  final Duration animationDuration;  const OverlayAnimation({
    super.key,
    required this.showBust,
    required this.showTurnChange,
    this.showLetterReceived = false,
    this.showPlayerEliminated = false,
    this.bgColor,
    required this.lastTurnPoints,
    required this.lastTurnLabels,
    required this.nextPlayerName,
    this.letterReceivedPlayer = '',
    this.letterReceivedLetters = '',
    this.size = OverlaySize.large,
    this.animationDuration = const Duration(milliseconds: 300),
  });@override
  Widget build(BuildContext context) {
    // Calculate font sizes based on size variant
    double bustFontSize = 72;
    double turnNameFontSize = 36;
    double turnTextFontSize = 28;
    
    switch (size) {
      case OverlaySize.small:
        bustFontSize = 48;
        turnNameFontSize = 24;
        turnTextFontSize = 18;
        break;
      case OverlaySize.medium:
        bustFontSize = 64;
        turnNameFontSize = 32;
        turnTextFontSize = 24;
        break;
      case OverlaySize.large:
        bustFontSize = 72;
        turnNameFontSize = 36;
        turnTextFontSize = 28;
        break;
    }      // Use theme colors if bgColor not provided
    final backgroundColor = bgColor ?? (showBust 
        ? AppColors.bustOverlayRed 
        : (showLetterReceived || showPlayerEliminated)
            ? AppColors.bustOverlayRed  // Red for letter received and elimination
            : AppColors.turnChangeBlue);
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Center(      child: showBust
            ? Text('BUST',
                style: AppTextStyles.bustOverlay().copyWith(
                  fontSize: bustFontSize,
                ))
            : showPlayerEliminated
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$letterReceivedPlayer is eliminated!',
                        style: AppTextStyles.bustOverlay().copyWith(
                          fontSize: turnNameFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12 * (turnNameFontSize / 40)),
                      Text(
                        '$letterReceivedPlayer is a DONKEY! 🐴',
                        style: AppTextStyles.bustOverlay().copyWith(
                          fontSize: turnTextFontSize + 4,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  )
                : showLetterReceived
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$letterReceivedPlayer got a letter!',
                            style: AppTextStyles.bustOverlay().copyWith(
                              fontSize: turnNameFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12 * (turnNameFontSize / 40)),
                          Text(
                            'Letters: ${letterReceivedLetters.split('').join('-')}',
                            style: AppTextStyles.bustOverlay().copyWith(
                              fontSize: turnTextFontSize + 4,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      )
                : showTurnChange
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Scored: $lastTurnPoints',
                            style: AppTextStyles.turnChangeOverlay().copyWith(
                              fontSize: turnNameFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8 * (turnNameFontSize / 40)),
                          Text(
                            lastTurnLabels,
                            style: AppTextStyles.turnChangeOverlay().copyWith(
                              fontSize: turnTextFontSize,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                      SizedBox(height: 8 * (turnNameFontSize / 40)),
                      Text(
                        "It's $nextPlayerName's turn!",
                        style: AppTextStyles.turnChangeOverlay().copyWith(
                          fontSize: turnNameFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}

class OverlayWidget extends StatelessWidget {
  final TraditionalGameController ctrl;
  final AnimationController bustController;
  final AnimationController turnController;
  final Animation<Color?> bustColorAnim;
  final Animation<Color?> turnColorAnim;

  const OverlayWidget({
    super.key,
    required this.ctrl,
    required this.bustController,
    required this.turnController,
    required this.bustColorAnim,
    required this.turnColorAnim,
  });

  @override
  Widget build(BuildContext context) {
    // compute next‐player name
    final nextIndex = (ctrl.currentPlayer + 1) % ctrl.players.length;
    final nextName = ctrl.players[nextIndex];

    return Stack(
      children: [
        if (ctrl.showBust || ctrl.showTurnChange)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([bustController, turnController]),
              builder: (_, __) => OverlayAnimation(
                showBust: ctrl.showBust,
                showTurnChange: ctrl.showTurnChange,                bgColor: ctrl.showBust
                    ? bustColorAnim.value!
                    : turnColorAnim.value!,
                lastTurnPoints: ctrl.lastTurnPoints(),
                lastTurnLabels: ctrl.lastTurnLabels(),
                nextPlayerName: nextName,
                size: OverlaySize.large,
              ),
            ),
          ),
      ],
    );
  }
}