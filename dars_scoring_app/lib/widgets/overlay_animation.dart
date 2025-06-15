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
  
  /// Background color for the overlay
  final Color? bgColor;
  
  /// Points scored in the last turn
  final String lastTurnPoints;
  
  /// Labels for darts thrown in the last turn
  final String lastTurnLabels;
  
  /// Name of the next player
  final String nextPlayerName;

  /// Size variant for the overlay
  final OverlaySize size;

  const OverlayAnimation({
    super.key,
    required this.showBust,
    required this.showTurnChange,
    this.bgColor,
    required this.lastTurnPoints,
    required this.lastTurnLabels,
    required this.nextPlayerName,
    this.size = OverlaySize.large,
  });  @override
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
    }
    
    // Use theme colors if bgColor not provided
    final backgroundColor = bgColor ?? (showBust 
        ? AppColors.bustOverlayRed 
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
                        "$nextPlayerName's turn!",
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