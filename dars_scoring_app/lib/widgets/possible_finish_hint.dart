import 'package:flutter/material.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/services/checkout_service.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';

/// Displays the best finish options based on the remaining score and darts.
class PossibleFinishHint extends StatelessWidget {

  const PossibleFinishHint({
    Key? key,
    required this.ctrl,
    this.fontSize = 18,
  }) : super(key: key);
  final TraditionalGameController ctrl;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final score = ctrl.scores[ctrl.currentPlayer];
    final dartsLeft = 3 - ctrl.dartsThrown;
    final checkoutPath = CheckoutService.getBestCheckout(
      score,
      dartsLeft,
      ctrl.checkoutRule,
    );

    if (checkoutPath.isNotEmpty) {
      return Text(
        'Best finish: ${checkoutPath.join(" ")}',
        style: TextStyle(
          fontSize: fontSize,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      );
    }

    return Text(
      'No finish possible',
      style: TextStyle(
        fontSize: fontSize,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }
}
