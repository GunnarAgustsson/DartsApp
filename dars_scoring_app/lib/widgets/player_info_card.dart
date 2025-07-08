import 'package:flutter/material.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/utils/string_utils.dart';
import 'dart_icons_row.dart';
import 'possible_finish_hint.dart';

/// Displays the current player's name, score, last darts icons,
/// and possible finish hint in a styled card.
class PlayerInfoCard extends StatelessWidget {

  const PlayerInfoCard({
    super.key,
    required this.ctrl,
    this.playerNameFontSize = 32,
    this.playerScoreFontSize = 64,
    this.dartIconSize = 32,
    this.possibleFinishFontSize = 16,
  });
  final TraditionalGameController ctrl;
  final double playerNameFontSize;
  final double playerScoreFontSize;
  final double dartIconSize;
  final double possibleFinishFontSize;

  @override
  Widget build(BuildContext context) {
    final act = ctrl.activePlayers;
    if (act.isEmpty) return const SizedBox.shrink();

    final actScores = act.map((p) => ctrl.scoreFor(p)).toList();
    final curIdx = ctrl.activeCurrentIndex;
    final name = shortenName(act[curIdx], maxLength: 12);

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.symmetric(
          vertical: 16 * (playerNameFontSize / 42),
          horizontal: 24 * (playerNameFontSize / 42),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16 * (playerNameFontSize / 42)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8 * (playerNameFontSize / 42),
              offset: Offset(0, 2 * (playerNameFontSize / 42)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: playerNameFontSize,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8 * (playerNameFontSize / 42)),
            Text(
              '${actScores[curIdx]}',
              style: TextStyle(
                fontSize: playerScoreFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8 * (playerNameFontSize / 42)),
            DartIconsRow(ctrl: ctrl, iconSize: dartIconSize),
            SizedBox(height: 8 * (playerNameFontSize / 42)),
            PossibleFinishHint(ctrl: ctrl, fontSize: possibleFinishFontSize),
          ],
        ),
      ),
    );
  }
}
