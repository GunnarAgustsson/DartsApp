import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';

/// Renders the last darts thrown as text labels and blank dart icons for remaining throws.
class DartIconsRow extends StatelessWidget {

  const DartIconsRow({
    Key? key,
    required this.ctrl,
    this.iconSize = 32,
  }) : super(key: key);
  final TraditionalGameController ctrl;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final name = ctrl.players[ctrl.currentPlayer];
    final used = ctrl.dartsThrown.clamp(0, 3);
    final remaining = 3 - used;

    final allThrows = ctrl.currentGame.throws
        .where((t) => t.player == name)
        .toList();
    final recent = allThrows.length >= used
        ? allThrows.sublist(allThrows.length - used)
        : allThrows;

    final activeTextStyle = TextStyle(
      fontSize: iconSize * 0.8,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Theme.of(context).primaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var t in recent)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4 * (iconSize / 32)),
            child: Text(
              t.value == 0
                  ? 'M'
                  : t.value == 50
                      ? 'DB'
                      : t.multiplier == 2
                          ? 'D${t.value}'
                          : t.multiplier == 3
                              ? 'T${t.value}'
                              : '${t.value}',
              style: activeTextStyle,
            ),
          ),
        for (int i = 0; i < remaining; i++) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4 * (iconSize / 32)),
            child: SvgPicture.asset(
              'assets/icons/dart-icon.svg',
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ],
      ],
    );
  }
}
