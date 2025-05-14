// ─────────────────────────────────────────────────────────────────────────────
// SECTION: Imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTION: TraditionalGameController
// Encapsulates all scoring rules, state management, and history persistence.
class TraditionalGameController extends ChangeNotifier {
  // — Public configuration/state —
  final int startingScore;            // e.g. 301, 501
  final List<String> players;         // turn order names

  late GameHistory currentGame;       // persistent game record
  late List<int> scores;              // current scores by player index
  int currentPlayer = 0;              // index of active player
  int dartsThrown = 0;                // throws this turn (0–3)
  int turnStartScore = 0;             // score at beginning of turn
  int multiplier = 1;                 // current x1/x2/x3 setting
  bool isTurnChanging = false;        // if we’re in between‐turn cooldown
  bool showBust = false;              // flag to flash “BUST”
  bool showTurnChange = false;        // flag to flash turn‐change
  CheckoutRule checkoutRule;          // finish rule (double out, etc.)
  String? lastWinner;                 // non‐null once game completes

  // New: track players who have completed
  final List<String> _finishedPlayers = [];

  // New: flag + last finisher for UI
  bool showPlayerFinished = false;
  String? lastFinisher;

  // Internal dependencies
  final AudioPlayer _audio = AudioPlayer();

  /// Public getter: all players who have *not* finished yet
  List<String> get activePlayers =>
    players.where((p) => !_finishedPlayers.contains(p)).toList();

  /// Public getter: index in [activePlayers] of the current turn
  int get activeCurrentIndex =>
    activePlayers.indexOf(players[currentPlayer]);

  /// Public getter: index in [activePlayers] of next turn
  int get activeNextIndex {
    final act = activePlayers;
    if (act.isEmpty) return 0;
    // map raw currentPlayer → act list, then +1 mod act.length
    final curName = players[currentPlayer];
    final idx = act.indexOf(curName);
    return (idx + 1) % act.length;
  }

  /// Return the score for a given player name
  int scoreFor(String player) => scores[players.indexOf(player)];

  /// Constructor: initializes state, resumes history if provided.
  TraditionalGameController({
    required this.startingScore,
    required this.players,
    GameHistory? resumeGame,
  })  : currentGame = resumeGame ?? 
            GameHistory(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              players: players,
              createdAt: DateTime.now(),
              modifiedAt: DateTime.now(),
              throws: [],
              completedAt: null,
              gameMode: startingScore,
            ),
        checkoutRule = CheckoutRule.openFinish {
    // Initialize scores list
    scores = List<int>.filled(players.length, startingScore);

    // If resuming, load prior throws & scores
    if (resumeGame != null) _loadFromHistory(resumeGame);

    // Async load of user‐preferred finish rule
    SharedPreferences.getInstance().then((prefs) {
      checkoutRule =
          CheckoutRule.values[prefs.getInt('checkoutRule') ?? 0];
      notifyListeners();
    });

    // when each sound finishes, release the player so it can be re-used immediately
    _audio.setReleaseMode(ReleaseMode.stop);
  }

  /// Private: replay history to restore scores, current player, etc.
  Future<void> _loadFromHistory(GameHistory resume) async {
    for (var t in resume.throws) {
      final idx = players.indexOf(t.player);
      scores[idx] = t.resultingScore;
    }
    currentPlayer = resume.currentPlayer;
    dartsThrown   = resume.dartsThrown;
    notifyListeners();
  }

  // ───── Public API ─────────────────────────────────────────────────────────

  /// Toggle the multiplier (x1/x2/x3)
  Future<void> setMultiplier(int v) async {
    multiplier = (multiplier == v) ? 1 : v;
    notifyListeners();
  }

  /// Main scoring method: apply a throw value (0,1–20,25,50)
  Future<void> score(int value) async {
    // Haptic feedback & dart‐throw sound
    HapticFeedback.mediumImpact();

    // stop any in-flight sound, so play() will always start from zero
    await _audio.stop();

    // no need to await the entire playback; this returns once playback has begun
    _audio.play(
      AssetSource('sound/dart_throw.mp3'),
      volume: 0.5,
    );

    // On first dart of turn, remember starting score
    if (dartsThrown == 0) turnStartScore = scores[currentPlayer];

    // Compute effective hit (apply multiplier except for bull/outer bull)
    final hit =
        (value == 25 || value == 50) ? value : value * multiplier;
    final before = scores[currentPlayer];
    final after = before - hit;

    // Determine bust or win based on checkoutRule
    bool isBust = false, isWin = false;
    switch (checkoutRule) {
      case CheckoutRule.doubleOut:
        if (after < 0 || after == 1) {
          isBust = true;
        } else if (after == 0 &&
            (multiplier != 2 && value != 50)) isBust = true;
        else if (after == 0) isWin = true;
        break;
      case CheckoutRule.extendedOut:
        if (after < 0 || after == 1) {
          isBust = true;
        } else if (after == 0 &&
            (multiplier != 2 &&
                multiplier != 3 &&
                value != 50)) isBust = true;
        else if (after == 0) isWin = true;
        break;
      case CheckoutRule.exactOut:
        if (after < 0) {
          isBust = true;
        } else if (after == 0) {
          isWin = true;
        }
        break;
      case CheckoutRule.openFinish:
        if (after <= 0) isWin = true;
        break;
    }

    if (isBust) {
      // Reset to turn start score and flash bust
      scores[currentPlayer] = turnStartScore;
      dartsThrown = 0;
      showBust = true;

      // After delay, clear flag and advance turn
      Future.delayed(const Duration(seconds: 2), () {
        showBust = false;
        _advanceTurn();
      });
    } else {
      // Normal scoring: record throw and update state
      scores[currentPlayer] = after;
      currentGame.throws.add(DartThrow(
        player: players[currentPlayer],
        value: value,
        multiplier:
            (value == 25 || value == 50) ? 1 : multiplier,
        resultingScore: after,
        timestamp: DateTime.now(),
        wasBust: false,
      ));
      dartsThrown++;

      if (isWin) {
        final finisher = players[currentPlayer];

        // 1) record finisher for UI
        lastFinisher       = finisher;
        showPlayerFinished = true;

        // 2) first‐to‐zero → set winner/completedAt once
        if (currentGame.winner == null) {
          currentGame.winner      = finisher;
          currentGame.completedAt = DateTime.now();
          lastWinner              = finisher;
          await _saveHistory();
        }

        // 3) mark them finished (but keep them in the list)
        _finishedPlayers.add(finisher);

        // 4) immediately advance to the next active player
        //    so that activeCurrentIndex is always valid:
        int next = currentPlayer;
        do {
          next = (next + 1) % players.length;
        } while (_finishedPlayers.contains(players[next])
                 && _finishedPlayers.length < players.length);
        currentPlayer = next;

        // 5) reset this turn’s darts
        dartsThrown = 0;

        // 6) notify UI & bail out
        notifyListeners();
        return;
      } else if (dartsThrown >= 3) {
        // End of turn
        dartsThrown = 0;
        _advanceTurn();
      }
    }

    // Reset multiplier and save history
    multiplier = 1;
    currentGame.modifiedAt = DateTime.now();
    await _saveHistory();
    notifyListeners();
  }

  /// Call this from your UI after showing the “X finished” popup
  void clearPlayerFinishedFlag() {
    showPlayerFinished = false;
    lastFinisher       = null;
    notifyListeners();
  }

  /// Undo the most recent throw, but if the player hasn't thrown any darts
  /// this turn (dartsThrown == 0), first revert the turn to the previous player.
  Future<void> undoLastThrow() async {
    if (currentGame.throws.isEmpty) return;

    // 1) If start of turn (no darts thrown yet), step back to the player who threw last
    if (dartsThrown == 0) {
      final lastThrow = currentGame.throws.last;
      currentPlayer = players.indexOf(lastThrow.player);

      // Recompute how many darts they used in that turn
      final consec = currentGame.throws
          .reversed
          .takeWhile((t) => t.player == lastThrow.player)
          .length;
      dartsThrown = consec.clamp(0, 3);
    }

    // 2) Now remove that last throw record
    final last = currentGame.throws.removeLast();

    // 3) Restore that player's score to what it was before the throw
    final idx = players.indexOf(last.player);
    final prevThrows = currentGame.throws
        .where((t) => t.player == last.player)
        .toList();
    final prevScore = prevThrows.isNotEmpty
        ? prevThrows.last.resultingScore
        : startingScore;
    scores[idx] = prevScore;

    // 4) If that throw was a winning throw (score == 0), clear the win state
    if (last.resultingScore == 0) {
      lastWinner = null;
      currentGame.completedAt = null;
    }

    // 5) Decrement dartsThrown (we just “undid” one dart)
    dartsThrown = (dartsThrown - 1).clamp(0, 3);

    // 6) Persist updated history & notify UI
    currentGame
      ..currentPlayer = currentPlayer
      ..dartsThrown   = dartsThrown
      ..modifiedAt    = DateTime.now();
    await _saveHistory();
    notifyListeners();
  }

  // ───── Internal helpers ───────────────────────────────────────────────────

  /// Advance to next *active* player with a turn‐change flash
  void _advanceTurn() {
    showTurnChange = true;
    // Clear flash and update player after 1s
    Future.delayed(const Duration(seconds: 1), () {
      showTurnChange = false;

      // find next player who is not finished
      int next = currentPlayer;
      do {
        next = (next + 1) % players.length;
      } while (_finishedPlayers.contains(players[next])
               && _finishedPlayers.length < players.length);

      currentPlayer = next;
      dartsThrown   = 0;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Persist the game history list in SharedPreferences
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // sync the live state into the history record:
    currentGame
      ..currentPlayer = currentPlayer
      ..dartsThrown   = dartsThrown
      ..modifiedAt    = DateTime.now();

    final games = prefs.getStringList('games_history') ?? [];
    final json = jsonEncode(currentGame.toJson());
    // Replace or append this game’s entry
    final idx = games.indexWhere((g) {
      return jsonDecode(g)['id'] == currentGame.id;
    });
    if (idx < 0) {
      games.add(json);
    } else {
      games[idx] = json;
    }

    await prefs.setStringList('games_history', games);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION: Finish Helpers Extension
// Convenience methods to display last-turn stats in UI.
extension TraditionalGameControllerFinishHelpers
    on TraditionalGameController {
  /// Returns the total points scored last turn as a string.
  String lastTurnPoints() {
    final diff = turnStartScore - scores[currentPlayer];
    return diff > 0 ? '$diff' : '0';
  }

  /// Returns a label like "T20 5 D10" for the last darts thrown.
  String lastTurnLabels() {
    final who = players[currentPlayer];
    final used = dartsThrown.clamp(0, 3);
    final all = currentGame.throws
        .where((t) => t.player == who)
        .toList();
    final recent = all.length >= used
        ? all.sublist(all.length - used)
        : all;

    return recent.map((t) {
      if (t.value == 0) return 'M';
      if (t.value == 50) return 'BULL';
      if (t.multiplier == 2) return 'D${t.value}';
      if (t.multiplier == 3) return 'T${t.value}';
      return '${t.value}';
    }).join(' ');
  }
}