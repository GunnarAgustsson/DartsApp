// ─────────────────────────────────────────────────────────────────────────────
// SECTION: Imports
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dars_scoring_app/models/game_history.dart'; // Provides GameHistory and DartThrow
import 'package:dars_scoring_app/data/possible_finishes.dart'; // Provides CheckoutRule and bestCheckouts
import 'package:dars_scoring_app/services/history_repository.dart';
import 'package:dars_scoring_app/services/sound_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTION: TraditionalGameController
/// A controller that manages all scoring rules, player turns, and history persistence
/// for a traditional darts game (e.g., 301, 501). It handles bust logic, finish rules,
/// undo functionality, and sound/haptic feedback.
class TraditionalGameController extends ChangeNotifier {
  // Constants for timing
  static const Duration _bustDisplayDuration = Duration(seconds: 2);
  static const Duration _turnChangeDuration = Duration(seconds: 1);
  static const Duration _saveDebounceDuration = Duration(milliseconds: 500);

  // — Public configuration/state —
  final int startingScore;            // e.g. 301, 501
  final List<String> players;         // turn order names

  late GameHistory currentGame;       // persistent game record
  late List<int> scores;              // current scores by player index
  int currentPlayer = 0;              // index of active player
  int dartsThrown = 0;                // throws this turn (0–3)
  int turnStartScore = 0;             // score at beginning of turn
  int multiplier = 1;                 // current x1/x2/x3 setting
  bool isTurnChanging = false;        // if we're in between‐turn cooldown
  bool showBust = false;              // flag to flash "BUST"
  bool showTurnChange = false;        // flag to flash turn‐change
  CheckoutRule checkoutRule;          // finish rule (double out, etc.)
  String? lastWinner;                 // non‐null once game completes

  // New: track players who have completed
  final List<String> _finishedPlayers = [];

  // New: flag + last finisher for UI
  bool showPlayerFinished = false;
  String? lastFinisher;

  // Internal services
  final HistoryRepository _repo = HistoryRepository();
  final SoundPlayer _sound = SoundPlayer();
  
  // Timers for cancellable operations
  Timer? _bustTimer;
  Timer? _turnChangeTimer;
  Timer? _saveTimer;

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

  /// Returns the current score for the given player name.
  int scoreFor(String player) => scores[players.indexOf(player)];

  /// Creates a new game controller with [startingScore], [players], and optional [initialRule].
  /// If [resumeGame] is provided, state is restored; if [initialRule] is provided, it overrides persisted preference.
  TraditionalGameController({
    required this.startingScore,
    required this.players,
    GameHistory? resumeGame,
    CheckoutRule? initialRule,
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
        checkoutRule = initialRule ?? CheckoutRule.openFinish {
    // Initialize scores list
    scores = List<int>.filled(players.length, startingScore);

    // If resuming, load prior throws & scores
    if (resumeGame != null) _loadFromHistory(resumeGame);

    // Async load of user‐preferred finish rule only if not injected
    if (initialRule == null) _initCheckoutRule();
  }

  /// Load the user's preferred checkout rule asynchronously
  Future<void> _initCheckoutRule() async {
    try {
      checkoutRule = await _repo.getCheckoutRule() as CheckoutRule;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading checkout rule: $e');
      // Default already set in constructor
    }
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
  /// This method handles sound/haptic feedback, scoring, bust/win logic,
  /// turn advancement, and debounced save to history.
  Future<void> score(int value) async {
    // Play sound and haptic feedback
    await _sound.playDartSound();
     
    // On first dart of the turn, record starting score for potential bust reset
    if (dartsThrown == 0) turnStartScore = scores[currentPlayer];

    // Calculate hit and resulting score
    final hit = _calculateEffectiveHit(value);
    final before = scores[currentPlayer];
    final after = before - hit;
    
    // Always record the throw first
    scores[currentPlayer] = after;
    currentGame.throws.add(DartThrow(
      player: players[currentPlayer],
      value: value,
      multiplier: (value == 25 || value == 50) ? 1 : multiplier,
      resultingScore: after,
      timestamp: DateTime.now(),
      wasBust: false,
    ));
    
    // NOW handle bust or win scenarios
    if (_handleBustOrWin(after, value)) return;

    // Continue with normal flow for non-bust, non-win throws
    dartsThrown++;
    if (dartsThrown >= 3) {
      dartsThrown = 0;
      _advanceTurn();
    }
    
    // Reset multiplier and save history
    multiplier = 1;
    currentGame.modifiedAt = DateTime.now();
    _debouncedSaveHistory();  // schedules _repo.saveGameHistory
    notifyListeners();
  }

  /// Calculate the effective hit value with multiplier
  int _calculateEffectiveHit(int value) {
    // Bull and outer bull have fixed values, others use multiplier
    return (value == 25 || value == 50) ? value : value * multiplier;
  }

  /// Determine if a throw results in a bust or win based on the [checkoutRule].
  /// Returns true if the throw was handled (bust or win), false otherwise.
  bool _handleBustOrWin(int afterScore, int dartValue) {
    bool isBust = false, isWin = false;
    
    // Choose bust/win conditions for each finish rule
    switch (checkoutRule) {
      case CheckoutRule.doubleOut:
        // Double-out: bust if score < 0 or exactly 1, win only on double or bull
        if (afterScore < 0 || afterScore == 1) {
          isBust = true;
        } else if (afterScore == 0 &&
            (multiplier != 2 && dartValue != 50)) isBust = true;
        else if (afterScore == 0) isWin = true;
        break;
      case CheckoutRule.extendedOut:
        // Extended-out: similar to double, but allows triple 20 as a win
        if (afterScore < 0 || afterScore == 1) {
          isBust = true;
        } else if (afterScore == 0 &&
            (multiplier != 2 &&
                multiplier != 3 &&
                dartValue != 50)) isBust = true;
        else if (afterScore == 0) isWin = true;
        break;
      case CheckoutRule.exactOut:
        // Exact-out: win only if score is reduced to exactly 0
        if (afterScore < 0) {
          isBust = true;
        } else if (afterScore == 0) {
          isWin = true;
        }
        break;
      case CheckoutRule.openFinish:
        // Open finish: any score reduction to 0 or below is a win
        if (afterScore <= 0) isWin = true;
        break;
    }

    if (isBust) {
      _handleBust(); // handle bust reset and turn change
      return true;
    }
    if (isWin) {
      _handleWin(); // record finisher and update state
      return true;
    }
    return false;
  }

  /// Handle a busted turn
  void _handleBust() {
    // Reset to turn start score and flash bust
    scores[currentPlayer] = turnStartScore;
    dartsThrown = 0;
    showBust = true;
    notifyListeners();

    // Cancel any existing timer
    _bustTimer?.cancel();
    
    // After delay, clear flag and advance turn
    _bustTimer = Timer(_bustDisplayDuration, () {
      showBust = false;
      _advanceTurn();
    });
  }

  /// Handle a winning throw
  void _handleWin() {
    final finisher = players[currentPlayer];

    // 1) record finisher for UI
    lastFinisher = finisher;
    showPlayerFinished = true;

    // 2) first‐to‐zero → set winner/completedAt once
    if (currentGame.winner == null) {
      currentGame.winner = finisher;
      currentGame.completedAt = DateTime.now();
      lastWinner = finisher;
      _repo.saveGameHistory(currentGame); // immediate save for win
    }

    // 3) mark them finished (but keep them in the list)
    _finishedPlayers.add(finisher);

    // 4) find next active player
    currentPlayer = _findNextActivePlayer(currentPlayer);

    // 5) reset this turn's darts
    dartsThrown = 0;

    // 6) notify UI
    notifyListeners();
  }

  /// Find the next active player starting from the given index
  int _findNextActivePlayer(int startingFrom) {
    int next = startingFrom;
    do {
      next = (next + 1) % players.length;
    } while (_finishedPlayers.contains(players[next]) && 
             _finishedPlayers.length < players.length);
    return next;
  }

  /// Call this from your UI after showing the "X finished" popup
  void clearPlayerFinishedFlag() {
    showPlayerFinished = false;
    lastFinisher = null;
    notifyListeners();
  }

  /// Undo the most recent throw, but if the player hasn't thrown any darts
  /// this turn (dartsThrown == 0), first revert the turn to the previous player.
  Future<void> undoLastThrow() async {
    if (currentGame.throws.isEmpty) return;

    // Cancel pending visual flashes/timers to prevent race conditions
    _bustTimer?.cancel();
    _turnChangeTimer?.cancel();
    showBust = false;
    showTurnChange = false;

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
      
      // Remove player from finished list
      _finishedPlayers.remove(last.player);
    }

    // 5) Decrement dartsThrown (we just "undid" one dart)
    dartsThrown = (dartsThrown - 1).clamp(0, 3);

    // 6) Persist updated history & notify UI
    currentGame
      ..currentPlayer = currentPlayer
      ..dartsThrown = dartsThrown
      ..modifiedAt = DateTime.now();
    await _repo.saveGameHistory(currentGame);
    notifyListeners();
  }

  // ───── Internal helpers ───────────────────────────────────────────────────

  /// Advance to next *active* player with a turn‐change flash
  void _advanceTurn() {
    // Cancel any existing timer
    _turnChangeTimer?.cancel();
    
    showTurnChange = true;
    notifyListeners();
    
    // Clear flash and update player after delay
    _turnChangeTimer = Timer(_turnChangeDuration, () {
      showTurnChange = false;
      currentPlayer = _findNextActivePlayer(currentPlayer);
      dartsThrown = 0;
      notifyListeners();
    });
  }

  /// Debounced history saving to reduce frequency of writes
  void _debouncedSaveHistory() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, () {
      _repo.saveGameHistory(currentGame);
    });
  }

  @override
  void dispose() {
    // Clean up timers
    _bustTimer?.cancel();
    _turnChangeTimer?.cancel();
    _saveTimer?.cancel();
    
    // Dispose audio resources
    _sound.dispose();
    
    super.dispose();
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
      if (t.value == 0) return 'M';  // Miss
      if (t.value == 50) return 'DB'; // Double Bull (was BULL)
      if (t.value == 25) return '25'; // Single Bull (was missing)
      if (t.multiplier == 2) return 'D${t.value}';
      if (t.multiplier == 3) return 'T${t.value}';
      return '${t.value}';
    }).join(' ');
  }
}