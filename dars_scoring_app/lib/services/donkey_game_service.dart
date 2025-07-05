import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/donkey_game.dart';
import '../models/app_enums.dart';
import '../services/settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Donkey Game Service - Handles HORSE-style darts game logic
// ─────────────────────────────────────────────────────────────────────────────

class DonkeyGameController extends ChangeNotifier {
  // Game state
  late DonkeyGameHistory _gameHistory;
  late List<String> _players;
  int _currentPlayerIndex = 0;
  int _dartsThrown = 0;  int _currentTurnScore = 0;
  final List<String> _currentTurnDartLabels = [];
  
  // Last turn data for animations
  int _lastTurnScore = 0;
  String _lastTurnPlayer = '';
  
  bool _showTurnChange = false;
  bool _isTurnChanging = false;
  bool _showPlayerFinished = false;
  String? _lastFinisher;
  bool _showLetterReceived = false;
  String? _letterReceivedPlayer;
  String? _letterReceivedLetters;
  bool _showPlayerEliminated = false;
  String? _eliminatedPlayer;// Animation
  Duration _animationDuration = const Duration(milliseconds: 400);
  final bool _isTest;
  bool _isDisposed = false;

  // Constructor
  DonkeyGameController({
    required List<String> players,
    DonkeyGameHistory? resumeGame,
    bool randomOrder = false,
    DonkeyVariant variant = DonkeyVariant.oneDart,
    bool isTest = false,
  }) : _isTest = isTest {
    _initializeGame(players, resumeGame, randomOrder, variant);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  /// Getters
  // ─────────────────────────────────────────────────────────────────────────────

  List<String> get players => _players;
  int get currentPlayer => _currentPlayerIndex;
  int get dartsThrown => _dartsThrown;
  int get currentTurnScore => _currentTurnScore;
  List<String> get currentTurnDartLabels => _currentTurnDartLabels;
  
  // Last turn data for animations
  int get lastTurnScore => _lastTurnScore;
  String get lastTurnPlayer => _lastTurnPlayer;
  
  bool get showTurnChange => _showTurnChange;
  bool get isTurnChanging => _isTurnChanging;
  bool get showPlayerFinished => _showPlayerFinished;
  String? get lastFinisher => _lastFinisher;
  bool get showLetterReceived => _showLetterReceived;
  String? get letterReceivedPlayer => _letterReceivedPlayer;
  String? get letterReceivedLetters => _letterReceivedLetters;
  bool get showPlayerEliminated => _showPlayerEliminated;
  String? get eliminatedPlayer => _eliminatedPlayer;
  Duration get animationDuration => _animationDuration;
  DonkeyGameHistory get gameHistory => _gameHistory;

  int get currentTarget => _gameHistory.currentTarget;
  String get targetSetBy => _gameHistory.targetSetBy;
  DonkeyVariant get variant => _gameHistory.variant;
  int get maxDartsPerTurn => variant.dartsPerTurn;

  /// Get player state for a specific player
  DonkeyPlayerState getPlayerState(String playerName) {
    return _gameHistory.playerStates[playerName]!;
  }

  /// Get active (non-eliminated) players
  List<String> get activePlayers => _gameHistory.activePlayers;
  /// Check if current turn is complete
  bool get isTurnComplete {
    return _dartsThrown >= maxDartsPerTurn;
  }

  /// Get letters for display (D-O-N-K-E-Y format)
  String getDisplayLetters(String playerName) {
    final letters = getPlayerState(playerName).letters;
    return letters.split('').join('-');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  /// Game Initialization
  // ─────────────────────────────────────────────────────────────────────────────

  void _initializeGame(
    List<String> players,
    DonkeyGameHistory? resumeGame,
    bool randomOrder,
    DonkeyVariant variant,
  ) {
    if (resumeGame != null) {
      _gameHistory = resumeGame;
      _players = _gameHistory.activePlayers;
      _currentPlayerIndex = 0; // Resume from first active player
    } else {
      _players = List.from(players);
      if (randomOrder) {
        _players.shuffle();
      }

      // Initialize player states
      final playerStates = <String, DonkeyPlayerState>{};
      for (final player in _players) {
        playerStates[player] = DonkeyPlayerState(name: player);
      }

      _gameHistory = DonkeyGameHistory(
        originalPlayers: _players,
        playerStates: playerStates,
        turns: [],
        variant: variant,
        startTime: DateTime.now(),
      );    }

    // Only load animation speed if not in test mode
    if (!_isTest) {
      _loadAnimationSpeed();
    }
  }
  /// Load animation speed from settings
  Future<void> _loadAnimationSpeed() async {
    final speed = await SettingsService.getAnimationSpeed();
    _animationDuration = speed.duration;
    notifyListeners();
  }

  /// Initialize and save a new game (call this after construction)
  Future<void> initializeNewGame() async {
    await _saveGame();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  /// Core Game Logic
  // ─────────────────────────────────────────────────────────────────────────────

  /// Score a hit with a given value and label (e.g., "D20", "T15")
  void score(int points, [String? label]) {
    if (_isTurnChanging || _showTurnChange || isTurnComplete) return;

    _currentTurnScore += points;
    _currentTurnDartLabels.add(label ?? points.toString());
    _dartsThrown++;

    // Auto-complete turn for 1-dart mode or when max darts reached
    if (variant == DonkeyVariant.oneDart || isTurnComplete) {
      _completeTurn();
    }

    notifyListeners();
  }

  /// Score a miss
  void scoreMiss() {
    if (_isTurnChanging || _showTurnChange || isTurnComplete) return;

    _currentTurnDartLabels.add('Miss');
    _dartsThrown++;

    // Auto-complete turn for 1-dart mode or when max darts reached
    if (variant == DonkeyVariant.oneDart || isTurnComplete) {
      _completeTurn();
    }

    notifyListeners();
  }
  /// Manually end the current turn
  void endTurn() {
    if (_isTurnChanging || _showTurnChange || _dartsThrown == 0) return;
    _completeTurn();
  }

  /// Complete the current turn
  void _completeTurn() {
    final currentPlayerName = _players[_currentPlayerIndex];
    final beatTarget = _currentTurnScore > currentTarget;

    // Create turn record
    final turn = DonkeyTurn(
      playerName: currentPlayerName,
      score: _currentTurnScore,
      dartLabels: List.from(_currentTurnDartLabels),
      beatTarget: beatTarget,
      receivedLetter: !beatTarget && currentTarget > 0, // Don't give letter on first turn
    );

    // Update game history
    _gameHistory = _gameHistory.copyWith(
      turns: [..._gameHistory.turns, turn],
    );    // Handle scoring logic
    if (beatTarget || currentTarget == 0) {
      // Player beat the target or set the first target
      _gameHistory = _gameHistory.copyWith(
        currentTarget: _currentTurnScore,
        targetSetBy: currentPlayerName,
      );    } else {
      // Player failed to beat target - give them a letter
      final currentState = getPlayerState(currentPlayerName);
      final newState = currentState.addLetter();
      
      final updatedStates = Map<String, DonkeyPlayerState>.from(_gameHistory.playerStates);
      updatedStates[currentPlayerName] = newState;
      
      // When a player gets a letter, their score becomes the new target
      _gameHistory = _gameHistory.copyWith(
        playerStates: updatedStates,
        currentTarget: _currentTurnScore,
        targetSetBy: currentPlayerName,
      );      // Set letter received state for animation (only if not eliminated)
      if (!newState.isEliminated) {
        _showLetterReceived = true;
        _letterReceivedPlayer = currentPlayerName;
        _letterReceivedLetters = newState.letters;
        
        // Auto-dismiss letter received animation after duration
        if (_animationDuration.inMilliseconds > 0) {
          Future.delayed(_animationDuration, () {
            if (!_isDisposed && _showLetterReceived) {
              clearLetterReceivedFlag();
            }
          });
        }
      } else {
        // Player is eliminated - show elimination animation instead
        _showPlayerEliminated = true;
        _eliminatedPlayer = currentPlayerName;
        
        // Auto-dismiss elimination animation after duration
        if (_animationDuration.inMilliseconds > 0) {
          Future.delayed(_animationDuration, () {
            if (!_isDisposed && _showPlayerEliminated) {
              clearPlayerEliminatedFlag();
            }
          });
        }
      }

      // Check if player is eliminated
      if (newState.isEliminated) {
        _handlePlayerElimination(currentPlayerName);
      }
    }

    // Save game and advance turn
    _saveGame();
    _advanceTurn();
  }

  /// Handle player elimination
  void _handlePlayerElimination(String playerName) {
    // Store the current player name before updating the list
    final currentPlayerName = _players[_currentPlayerIndex];
    
    // Update active players list
    final oldPlayersList = List<String>.from(_players);
    _players = _gameHistory.activePlayers;

    // Adjust current player index if needed
    if (_players.isNotEmpty) {
      // Find the new index of the current player
      final newIndex = _players.indexOf(currentPlayerName);
      if (newIndex != -1) {
        // Current player is still active, update index
        _currentPlayerIndex = newIndex;
      } else {
        // Current player was eliminated, adjust index to maintain turn order
        final eliminatedIndex = oldPlayersList.indexOf(playerName);
        if (eliminatedIndex <= _currentPlayerIndex) {
          // The eliminated player was before or at current position
          // Decrease index to account for removed player
          _currentPlayerIndex = (_currentPlayerIndex - 1).clamp(0, _players.length - 1);
        }
        // If eliminated player was after current position, no adjustment needed
        _currentPlayerIndex = _currentPlayerIndex.clamp(0, _players.length - 1);
      }
    }

    // Check if game is finished
    if (_gameHistory.isGameFinished) {
      _lastFinisher = _gameHistory.winner;
      _showPlayerFinished = true;
      
      _gameHistory = _gameHistory.copyWith(
        lastFinisher: _lastFinisher,
        endTime: DateTime.now(),
      );
    }
  }  /// Advance to next player's turn
  void _advanceTurn() {
    if (_gameHistory.isGameFinished) return;

    // Only show turn change animation if no special animation is shown
    if (!_showLetterReceived && !_showPlayerEliminated) {
      _showTurnChange = true;
    }
    _isTurnChanging = true;

    // Preserve last turn data for animations
    _lastTurnScore = _currentTurnScore;
    _lastTurnPlayer = _players[_currentPlayerIndex];

    // Reset turn state
    _currentTurnScore = 0;
    _currentTurnDartLabels.clear();
    _dartsThrown = 0;

    // Move to next active player
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;

    // Handle animation timing
    if (_animationDuration.inMilliseconds > 0) {
      Future.delayed(_animationDuration, () {
        if (!_isDisposed) {
          _showTurnChange = false;
          _isTurnChanging = false;
          notifyListeners();
        }
      });
    } else {
      _showTurnChange = false;
      _isTurnChanging = false;
    }

    notifyListeners();
  }

  /// Undo the last dart thrown
  void undoLastThrow() {
    if (_dartsThrown == 0) return;

    // Remove last dart
    _currentTurnDartLabels.removeLast();
    
    // Recalculate turn score from remaining darts
    _currentTurnScore = 0;
    for (final dartLabel in _currentTurnDartLabels) {
      _currentTurnScore += _parseDartScore(dartLabel);
    }
    
    _dartsThrown--;

    notifyListeners();
  }

  /// Clear player finished flag
  void clearPlayerFinishedFlag() {
    _showPlayerFinished = false;    _lastFinisher = null;
    notifyListeners();
  }  /// Clear letter received flag
  void clearLetterReceivedFlag() {
    _showLetterReceived = false;
    _letterReceivedPlayer = null;
    _letterReceivedLetters = null;
    
    // Reset turn change state that was suppressed
    _showTurnChange = false;
    _isTurnChanging = false;
    
    notifyListeners();
  }

  /// Clear player eliminated flag
  void clearPlayerEliminatedFlag() {
    _showPlayerEliminated = false;
    _eliminatedPlayer = null;
    
    // Reset turn change state that was suppressed
    _showTurnChange = false;
    _isTurnChanging = false;
    
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  /// Helper Functions
  // ─────────────────────────────────────────────────────────────────────────────

  /// Parse dart score from label
  int _parseDartScore(String dartLabel) {
    if (dartLabel == 'Miss') return 0;
    if (dartLabel == 'Bull') return 25;
    
    if (dartLabel.startsWith('D')) {
      final value = int.tryParse(dartLabel.substring(1)) ?? 0;
      return value * 2;
    }
    
    if (dartLabel.startsWith('T')) {
      final value = int.tryParse(dartLabel.substring(1)) ?? 0;
      return value * 3;
    }
    
    return int.tryParse(dartLabel) ?? 0;
  }

  /// Get last turn labels for animation
  List<String> lastTurnLabels() {
    if (_gameHistory.turns.isEmpty) return [];
    return _gameHistory.turns.last.dartLabels;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  /// Data Persistence
  // ─────────────────────────────────────────────────────────────────────────────  /// Save current game state
  Future<void> _saveGame() async {
    // Don't save games during testing
    if (_isTest) {
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing donkey games
      final List<String> existingGamesRaw = prefs.getStringList('donkey_games') ?? [];
      final List<DonkeyGameHistory> existingGames = [];
      
      // Parse existing games
      for (String rawGame in existingGamesRaw) {
        try {
          existingGames.add(DonkeyGameHistory.fromJson(jsonDecode(rawGame)));
        } catch (e) {
          debugPrint('Error parsing existing donkey game: $e');
        }
      }

      // Find existing game or add new one
      final gameId = '${_gameHistory.startTime.millisecondsSinceEpoch}';
      final existingIndex = existingGames.indexWhere((g) => 
        '${g.startTime.millisecondsSinceEpoch}' == gameId
      );

      if (existingIndex != -1) {
        // Update existing game
        existingGames[existingIndex] = _gameHistory;
      } else {
        // Add new game
        existingGames.add(_gameHistory);
      }

      // Keep only last 100 games
      if (existingGames.length > 100) {
        existingGames.removeRange(0, existingGames.length - 100);
      }

      // Save back to preferences
      final gamesJson = existingGames.map((g) => jsonEncode(g.toJson())).toList();
      await prefs.setStringList('donkey_games', gamesJson);
      
      debugPrint('Saved donkey game with ${_gameHistory.turns.length} turns');
    } catch (e) {
      debugPrint('Error saving Donkey game: $e');
    }
  }
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
