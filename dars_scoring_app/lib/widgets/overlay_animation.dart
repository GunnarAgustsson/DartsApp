import 'package:flutter/material.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';

class OverlayAnimation extends StatelessWidget {
  final bool showBust;
  final bool showTurnChange;
  final Color bgColor;
  final String lastTurnPoints;
  final String lastTurnLabels;
  final String nextPlayerName;
  final double bustFontSize;
  final double turnNameFontSize;
  final double turnTextFontSize;

  const OverlayAnimation({
    super.key,
    required this.showBust,
    required this.showTurnChange,
    required this.bgColor,
    required this.lastTurnPoints,
    required this.lastTurnLabels,
    required this.nextPlayerName,
    required this.bustFontSize,
    required this.turnNameFontSize,
    required this.turnTextFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16 * (bustFontSize / 72)),
      ),
      child: Center(
        child: showBust
            ? Text('BUST',
                style: TextStyle(
                  fontSize: bustFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ))
            : showTurnChange
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Scored: $lastTurnPoints',
                        style: TextStyle(
                          fontSize: turnNameFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8 * (turnNameFontSize / 40)),
                      Text(
                        lastTurnLabels,
                        style: TextStyle(
                          fontSize: turnTextFontSize,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8 * (turnNameFontSize / 40)),
                      Text(
                        "$nextPlayerName's turn!",
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
                showTurnChange: ctrl.showTurnChange,
                bgColor: ctrl.showBust
                    ? bustColorAnim.value!
                    : turnColorAnim.value!,
                lastTurnPoints: ctrl.lastTurnPoints(),
                lastTurnLabels: ctrl.lastTurnLabels(),
                nextPlayerName: nextName,
                bustFontSize: 72,
                turnNameFontSize: 40,
                turnTextFontSize: 20,
              ),
            ),
          ),
      ],
    );
  }
}