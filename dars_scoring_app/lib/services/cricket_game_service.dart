import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/cricket_game.dart';

class CricketGameController extends ChangeNotifier {
  // Constants for timing
  static const Duration _turnChangeDuration = Duration(seconds: 2);
  static const Duration _saveDebounceDuration = Duration(milliseconds: 500);

  // Configuration
  final List<String> players;
  final bool randomOrder;

  // Game state
  late CricketGameHistory currentGame;
  int currentPlayer = 0;
  int dartsThrown = 0;
  int multiplier = 1;
  bool isTurnChanging = false;
  bool showTurnChange = false;
  String? lastWinner;

  // UI flags
  bool showPlayerFinished = false;
  String? lastFinisher;
  // Internal dependencies
  AudioPlayer? _audio;
  
  // Timers for cancellable operations
  Timer? _turnChangeTimer;
  Timer? _saveTimer;

  // Cricket numbers in order (20, 19, 18, 17, 16, 15, bull)
  static const List<int> cricketNumbers = [20, 19, 18, 17, 16, 15, 25];

  /// Public getter: get player state for a player
  CricketPlayerState getPlayerState(String playerName) {
    return currentGame.playerStates[playerName]!;
  }

  /// Public getter: get score for a player
  int scoreFor(String playerName) {
    return currentGame.playerStates[playerName]!.score;
  }

  /// Public getter: check if a number is closed for all players
  bool isNumberClosedForAll(int number) {
    return currentGame.playerStates.values
        .every((state) => state.isNumberClosed(number));
  }
  /// Check if a player can score on a number (they can hit it if they haven't closed it)
  bool canPlayerScoreOn(String playerName, int number) {
    final playerState = currentGame.playerStates[playerName]!;
    
    // Player can hit a number if they haven't closed it yet
    return !playerState.isNumberClosed(number);
  }

  /// Check if current player can score on a number
  bool canCurrentPlayerScoreOn(int number) {
    return canPlayerScoreOn(players[currentPlayer], number);
  }

  /// Score a miss (no points, just advance the turn)
  Future<void> scoreMiss() async {
    // Play sound and give haptic feedback
    _playDartSound();
    
    // Record the miss throw
    final cricketThrow = CricketThrow(
      player: players[currentPlayer],
      value: 0, // 0 represents a miss
      multiplier: 1,
      timestamp: DateTime.now(),
    );
    
    currentGame.throws.add(cricketThrow);    // Continue with normal flow
    dartsThrown++;
    if (dartsThrown >= 3) {
      dartsThrown = 0;
      _advanceTurn();
    }
    
    // Reset multiplier and save
    multiplier = 1;
    currentGame.modifiedAt = DateTime.now();
    _debouncedSave();
    
    notifyListeners();
  }  /// Constructor
  CricketGameController({
    required this.players,
    CricketGameHistory? resumeGame,
    this.randomOrder = false,
  }) : currentGame = resumeGame ?? 
            CricketGameHistory(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              players: players,
              createdAt: DateTime.now(),
              modifiedAt: DateTime.now(),
              throws: [],
              completedAt: null,
              currentPlayer: 0,
              dartsThrown: 0,
            ) {
      // If resuming, load prior state
    if (resumeGame != null) {
      _loadFromHistory(resumeGame);
    }    // Configure audio player - only if not in test environment
    if (!_isTestEnvironment()) {
      try {
        _audio = AudioPlayer();
        _audio?.setReleaseMode(ReleaseMode.stop);
      } catch (e) {
        // Ignore audio errors in test environment
        debugPrint('Audio initialization skipped: $e');
      }
    }
  }

  /// Load from history to restore state
  void _loadFromHistory(CricketGameHistory resume) {
    currentPlayer = resume.currentPlayer;
    dartsThrown = resume.dartsThrown;
    
    // Make sure to recreate the current game state from the resume object
    currentGame = resume;
    
    // Don't notify here as constructor is still running
  }

  /// Initialize and save a new game (call this after construction)
  Future<void> initializeNewGame() async {
    if (currentGame.throws.isEmpty) {
      await _saveGame();
    }
  }

  /// Toggle the multiplier (x1/x2/x3)
  Future<void> setMultiplier(int v) async {
    multiplier = (multiplier == v) ? 1 : v;
    notifyListeners();
  }
  /// Main scoring method: apply a throw value (15-20, 25)
  Future<void> score(int value) async {
    // Only allow cricket numbers
    if (!cricketNumbers.contains(value)) return;
    
    // Play sound and give haptic feedback
    _playDartSound();
    
    // Record the throw
    final cricketThrow = CricketThrow(
      player: players[currentPlayer],
      value: value,
      multiplier: multiplier,
      timestamp: DateTime.now(),
    );
    
    currentGame.throws.add(cricketThrow);
    
    // Apply the hit to the player's state
    final playerState = currentGame.playerStates[players[currentPlayer]]!;
    final hits = multiplier;
    
    // Add hits to the number (cap at 3 since we only need to close)
    final previousHits = playerState.hits[value]!;
    playerState.hits[value] = (previousHits + hits).clamp(0, 3);

    // Check for win condition (first to close all numbers wins)
    if (_checkWinCondition()) {
      _handleWin();
      return;
    }    // Continue with normal flow
    dartsThrown++;
    if (dartsThrown >= 3) {
      dartsThrown = 0;
      _advanceTurn();
    }
    
    // Reset multiplier and save
    multiplier = 1;
    currentGame.modifiedAt = DateTime.now();
    _debouncedSave();
    
    notifyListeners();
  }
  /// Check if current player has won
  bool _checkWinCondition() {
    final playerState = currentGame.playerStates[players[currentPlayer]];
    
    // Simple rule: first player to close all numbers wins
    return playerState!.allNumbersClosed;
  }

  /// Handle a winning throw
  void _handleWin() {
    final finisher = players[currentPlayer];    
    // Set winner and completion
    currentGame.winner = finisher;
    currentGame.completedAt = DateTime.now();
    lastWinner = finisher;
    
    // UI flags
    lastFinisher = finisher;
    showPlayerFinished = true;
    
    // Reset darts thrown
    dartsThrown = 0;
    
    // Save completed game
    _saveGame();
    
    // Notify
    notifyListeners();
  }

  /// Call this from your UI after showing the "X finished" popup
  void clearPlayerFinishedFlag() {
    showPlayerFinished = false;
    lastFinisher = null;
    notifyListeners();
  }

  /// Undo the most recent throw
  Future<void> undoLastThrow() async {
    if (currentGame.throws.isEmpty) return;

    // Cancel any pending timers
    _turnChangeTimer?.cancel();
    showTurnChange = false;

    // If start of turn (no darts thrown yet), step back to previous player
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

    // Remove the last throw
    final lastThrow = currentGame.throws.removeLast();
    
    // Revert the player state
    final playerState = currentGame.playerStates[lastThrow.player]!;
    final hits = lastThrow.hits;
    
    // Remove hits from the number
    final previousHits = playerState.hits[lastThrow.value]!;
    playerState.hits[lastThrow.value] = (previousHits - hits).clamp(0, 6);
    
    // Recalculate score by replaying all throws for this player
    _recalculatePlayerScore(lastThrow.player);

    // If that throw was a winning throw, clear the win state
    if (lastThrow.player == currentGame.winner) {
      lastWinner = null;
      currentGame.winner = null;
      currentGame.completedAt = null;
    }

    // Decrement darts thrown
    dartsThrown = (dartsThrown - 1).clamp(0, 3);    // Restore multiplier
    multiplier = lastThrow.multiplier;

    // Save and notify
    currentGame.modifiedAt = DateTime.now();
    _debouncedSave();
    notifyListeners();
  }  /// Recalculate a player's state from scratch based on all their throws
  void _recalculatePlayerScore(String playerName) {
    final playerState = currentGame.playerStates[playerName]!;
    
    // Reset score and hits (score is not used in simplified cricket)
    playerState.score = 0;
    for (int number in cricketNumbers) {
      playerState.hits[number] = 0;
    }
    
    // Replay all throws for this player
    for (final dartThrow in currentGame.throws) {
      if (dartThrow.player != playerName) continue;
      
      final value = dartThrow.value;
      final hits = dartThrow.hits;
      
      // Add hits (cap at 3 since we only need to close)
      playerState.hits[value] = (playerState.hits[value]! + hits).clamp(0, 3);
    }
  }

  /// Advance to next player with turn change animation
  void _advanceTurn() {
    _turnChangeTimer?.cancel();
    
    showTurnChange = true;
    notifyListeners();    _turnChangeTimer = Timer(_turnChangeDuration, () {
      showTurnChange = false;
      currentPlayer = (currentPlayer + 1) % players.length;
      dartsThrown = 0;
      
      // Update the current player in the game history and save
      currentGame.currentPlayer = currentPlayer;
      currentGame.dartsThrown = dartsThrown;
      _debouncedSave();
      
      notifyListeners();
    });
  }  /// Play dart sound
  void _playDartSound() {
    HapticFeedback.mediumImpact();
    try {
      _audio?.play(
        AssetSource('sound/dart_throw.mp3'),
        volume: 0.5,
      );
    } catch (e) {
      // Ignore audio errors in test environment
      debugPrint('Audio error: $e');
    }
  }  /// Save cricket game to SharedPreferences
  Future<void> _saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update current game state before saving
      currentGame
        ..currentPlayer = currentPlayer
        ..dartsThrown = dartsThrown
        ..modifiedAt = DateTime.now();

      // Get existing cricket games
      final cricketGames = prefs.getStringList('cricket_games') ?? [];
      
      // Convert game to JSON
      final json = jsonEncode(currentGame.toJson());
      
      // Find existing game or add new one
      final gameIndex = cricketGames.indexWhere((gameJson) {
        final gameData = jsonDecode(gameJson);
        return gameData['id'] == currentGame.id;
      });
        if (gameIndex >= 0) {
        // Update existing game
        cricketGames[gameIndex] = json;
      } else {
        // Add new game
        cricketGames.add(json);
      }

      // Save back to preferences
      await prefs.setStringList('cricket_games', cricketGames);
    } catch (e, stackTrace) {
      debugPrint('Error saving cricket game: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Debounced save to avoid too frequent writes
  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, () {
      _saveGame();
    });
  }

  /// Load a specific cricket game by ID
  static Future<CricketGameHistory?> loadGame(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cricketGames = prefs.getStringList('cricket_games') ?? [];
      
      for (final gameJson in cricketGames) {
        final gameData = jsonDecode(gameJson);
        if (gameData['id'] == gameId) {
          return CricketGameHistory.fromJson(gameData);
        }
      }
      
      debugPrint('Cricket game not found: $gameId');
      return null;
    } catch (e) {
      debugPrint('Error loading cricket game: $e');
      return null;
    }
  }  /// Get all saved cricket games
  static Future<List<CricketGameHistory>> getAllSavedGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cricketGames = prefs.getStringList('cricket_games') ?? [];
      
      final games = <CricketGameHistory>[];
      for (final gameJson in cricketGames) {
        try {
          final gameData = jsonDecode(gameJson);
          games.add(CricketGameHistory.fromJson(gameData));
        } catch (e) {
          debugPrint('Error parsing cricket game: $e');
        }
      }
      
      // Sort by most recent first
      games.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return games;
    } catch (e) {
      debugPrint('Error loading cricket games: $e');
      return [];
    }
  }

  /// Delete a cricket game
  static Future<bool> deleteGame(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cricketGames = prefs.getStringList('cricket_games') ?? [];
      
      final updatedGames = cricketGames.where((gameJson) {
        final gameData = jsonDecode(gameJson);
        return gameData['id'] != gameId;
      }).toList();
      
      await prefs.setStringList('cricket_games', updatedGames);
      debugPrint('Deleted cricket game: $gameId');
      return true;
    } catch (e) {
      debugPrint('Error deleting cricket game: $e');
      return false;
    }
  }

  /// Get all unfinished cricket games for resume
  static Future<List<CricketGameHistory>> getUnfinishedGames() async {
    final allGames = await getAllSavedGames();
    return allGames.where((game) => game.completedAt == null).toList();
  }

  /// Get labels for last turn darts
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
      if (t.value == 25) return t.multiplier == 2 ? 'DB' : '25';
      if (t.multiplier == 2) return 'D${t.value}';
      if (t.multiplier == 3) return 'T${t.value}';
      return '${t.value}';
    }).join(' ');
  }

  /// Get current turn dart labels
  List<String> get currentTurnDartLabels {
    final who = players[currentPlayer];
    final used = dartsThrown.clamp(0, 3);
    final all = currentGame.throws
        .where((t) => t.player == who)
        .toList();
    final recent = all.length >= used
        ? all.sublist(all.length - used)
        : all;    return recent.map((t) {
      if (t.value == 0) return 'M';  // Miss
      if (t.value == 25) return t.multiplier == 2 ? 'DB' : '25';
      if (t.multiplier == 2) return 'D${t.value}';
      if (t.multiplier == 3) return 'T${t.value}';
      return '${t.value}';
    }).toList();
  }  /// Check if running in test environment
  bool _isTestEnvironment() {
    // Simple check - try to detect if binding is null or test binding
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (e) {
      // If we can't access WidgetsBinding, assume we're in test
      return true;
    }
  }

  @override
  void dispose() {
    // Clean up timers
    _turnChangeTimer?.cancel();
    _saveTimer?.cancel();
    
    // Dispose audio resources
    _audio?.dispose();
    
    super.dispose();
  }
}