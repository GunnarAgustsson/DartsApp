// ─────────────────────────────────────────────────────────────────────────────
// SECTION: Imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTION: TraditionalGameController
// Encapsulates all scoring rules, state management, and history persistence.
class TraditionalGameController extends ChangeNotifier {  // Constants for timing
  static const Duration _bustDisplayDuration = Duration(seconds: 2);
  static const Duration _turnChangeDuration = Duration(seconds: 2); // Increased to 2 seconds
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

  // Internal dependencies
  final AudioPlayer _audio = AudioPlayer();
  
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
  /// Returns the labels of the darts thrown in the current turn.
  List<String> get currentTurnDartLabels {
    if (dartsThrown == 0) return [];

    final playerThrows =
        currentGame.throws.where((t) => t.player == players[currentPlayer]).toList();

    if (playerThrows.length < dartsThrown) return [];

    final recentThrows =
        playerThrows.sublist(playerThrows.length - dartsThrown);

    return recentThrows.map((t) {
      if (t.value == 0) return 'M';
      if (t.value == 50) return 'DB';
      if (t.value == 25) return '25';
      if (t.multiplier == 2) return 'D${t.value}';
      if (t.multiplier == 3) return 'T${t.value}';
      return '${t.value}';
    }).toList();
  }

  /// Return the score for a given player name
  int scoreFor(String player) => scores[players.indexOf(player)];

  /// Calculate the average score for a given player in the current game.
  double averageScoreFor(String player) {
    final playerThrows = currentGame.throws
        .where((t) => t.player == player && !t.wasBust) // Consider only non-bust throws
        .toList();

    if (playerThrows.isEmpty) {
      return 0.0;
    }

    double totalScoreFromThrows = 0;
    int validDartsCount = 0;

    // Iterate through throws to sum points and count darts
    for (var i = 0; i < playerThrows.length; i++) {
      final throwData = playerThrows[i];
      int pointsScoredThisDart = 0;

      if (i == 0) {
        // First throw for this player in the game
        pointsScoredThisDart = startingScore - throwData.resultingScore;
      } else {
        // Subsequent throws
        pointsScoredThisDart = playerThrows[i-1].resultingScore - throwData.resultingScore;
      }
      totalScoreFromThrows += pointsScoredThisDart;
      validDartsCount++;
    }
    
    // Calculate average per 3 darts
    if (validDartsCount == 0) return 0.0;
    return (totalScoreFromThrows / validDartsCount) * 3;
  }

  /// Constructor: initializes state, resumes history if provided.
  TraditionalGameController({
    required this.startingScore,
    required this.players,
    GameHistory? resumeGame,
    CheckoutRule? checkoutRule,
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
        checkoutRule = checkoutRule ?? CheckoutRule.doubleOut {
    // Initialize scores list
    scores = List<int>.filled(players.length, startingScore);

    // If resuming, load prior throws & scores
    if (resumeGame != null) _loadFromHistory(resumeGame);

    // Load user-preferred finish rule only if not explicitly provided
    if (checkoutRule == null) {
      _initCheckoutRule();
    }

    // Configure audio player
    _audio.setReleaseMode(ReleaseMode.stop);
  }

  /// Load the user's preferred checkout rule asynchronously
  Future<void> _initCheckoutRule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      checkoutRule = CheckoutRule.values[prefs.getInt('checkoutRule') ?? 0];
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
  Future<void> score(int value) async {
    // Play sound and give haptic feedback
    _playDartSound();
    
    // On first dart of turn, remember starting score
    if (dartsThrown == 0) turnStartScore = scores[currentPlayer];

    // Calculate hit and resulting score
    final hit = _calculateEffectiveHit(value);
    final before = scores[currentPlayer];
    final after = before - hit;
    
    // Record the throw BEFORE checking for bust/win
    // final isWinningThrow = (after == 0); // This variable was unused
    
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
    _debouncedSaveHistory();
    notifyListeners();
  }

  /// Play the dart throw sound with error handling
  void _playDartSound() {
    HapticFeedback.mediumImpact();
    try {
      // By simply calling play, we avoid a race condition that was present
      // with the previous `stop().then(play)` pattern. The `play` method
      // will automatically stop the currently playing sound before starting
      // the new one, which is the desired behavior for rapid button presses.
      _audio.play(
        AssetSource('sound/dart_throw.mp3'),
        volume: 0.5,
      );
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  /// Calculate the effective hit value with multiplier
  int _calculateEffectiveHit(int value) {
    // Bull and outer bull have fixed values, others use multiplier
    return (value == 25 || value == 50) ? value : value * multiplier;
  }

  /// Handle bust or win scenarios, returns true if handled
  bool _handleBustOrWin(int afterScore, int dartValue) {
    bool isBust = false, isWin = false;
    
    switch (checkoutRule) {
      case CheckoutRule.doubleOut:
        if (afterScore < 0 || afterScore == 1) {
          isBust = true;
        } else if (afterScore == 0 &&
            (multiplier != 2 && dartValue != 50)) isBust = true;
        else if (afterScore == 0) isWin = true;
        break;
      case CheckoutRule.extendedOut:
        if (afterScore < 0 || afterScore == 1) {
          isBust = true;
        } else if (afterScore == 0 &&
            (multiplier != 2 &&
                multiplier != 3 &&
                dartValue != 50)) isBust = true;
        else if (afterScore == 0) isWin = true;
        break;
      case CheckoutRule.exactOut:
        if (afterScore < 0) {
          isBust = true;
        } else if (afterScore == 0) {
          isWin = true;
        }
        break;
      case CheckoutRule.openFinish:
        if (afterScore <= 0) isWin = true;
        break;
    }

    if (isBust) {
      _handleBust();
      return true;
    }
    
    if (isWin) {
      _handleWin();
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
      _saveHistory(); // immediate save for win
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

    // Cancel any pending timers to avoid race conditions
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
    await _saveHistory();
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
      _saveHistory();
    });
  }

  /// Persist the game history list in SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // sync the live state into the history record:
      currentGame
        ..currentPlayer = currentPlayer
        ..dartsThrown = dartsThrown
        ..modifiedAt = DateTime.now();

      final games = prefs.getStringList('games_history') ?? [];
      final json = jsonEncode(currentGame.toJson());
      // Replace or append this game's entry
      final idx = games.indexWhere((g) {
        return jsonDecode(g)['id'] == currentGame.id;
      });
      if (idx < 0) {
        games.add(json);
      } else {
        games[idx] = json;
      }

      await prefs.setStringList('games_history', games);
    } catch (e) {
      debugPrint('Error saving game history: $e');
    }
  }
  
  @override
  void dispose() {
    // Clean up timers
    _bustTimer?.cancel();
    _turnChangeTimer?.cancel();
    _saveTimer?.cancel();
    
    // Dispose audio resources
    _audio.dispose();
    
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