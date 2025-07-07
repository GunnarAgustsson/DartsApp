import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/killer_player.dart';
import '../models/killer_game_history.dart';
import '../utils/killer_game_utils.dart';
import '../services/killer_game_state_service.dart';
import '../services/killer_game_history_service.dart';
import '../widgets/interactive_dartboard.dart';
import '../widgets/dart_icon.dart';
import '../widgets/game_overlay_animation.dart';

/// Main screen for playing Killer darts game
class KillerGameScreen extends StatefulWidget {

  const KillerGameScreen({
    super.key,
    required this.playerNames,
    required this.randomOrder,
  });
  final List<String> playerNames;
  final bool randomOrder;

  @override
  State<KillerGameScreen> createState() => _KillerGameScreenState();
}

class _KillerGameScreenState extends State<KillerGameScreen> {
  // Game state
  List<KillerPlayer> players = [];
  int currentPlayerIndex = 0;
  DateTime? gameStartTime;
  int totalDartsThrown = 0;
  bool isGameCompleted = false;
  String? winner;

  // UI state
  final TextEditingController _scoreController = TextEditingController();
  final FocusNode _scoreFocusNode = FocusNode();
  bool _isLoading = false;
  
  // New state for button-based input
  int _selectedMultiplier = 1;
  
  // Dart tracking state
  final List<DartResult> _currentTurnDarts = [];
  final int _maxDartsPerTurn = 3;

  // Overlay animation state
  bool _showOverlay = false;
  GameOverlayType? _overlayType;
  String _overlayPlayerName = '';

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _scoreFocusNode.dispose();
    super.dispose();
  }

  /// Initialize the game with random territories
  void _initializeGame() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if there's an existing game to resume
      final existingGame = await KillerGameStateService.loadGameState();
      
      if (existingGame != null && !existingGame.isCompleted) {
        // Resume existing game
        players = existingGame.players;
        currentPlayerIndex = existingGame.currentPlayerIndex;
        gameStartTime = existingGame.gameStartTime;
        totalDartsThrown = existingGame.totalDartsThrown;
        isGameCompleted = existingGame.isCompleted;
        winner = existingGame.winner;
        
        // Show resume confirmation
        final shouldResume = await _showResumeDialog();
        if (!shouldResume) {
          // Start new game instead
          await _startNewGame();
        }
      } else {
        // Start new game
        await _startNewGame();
      }
    } catch (e) {
      _showErrorDialog('Failed to initialize game: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Process a dart throw
  void _processDart(String scoreInput) {
    if (isGameCompleted || _isLoading) return;

    final hit = KillerGameUtils.parseDartScore(scoreInput);
    if (hit == null) {
      _showErrorDialog('Invalid score format. Use: 20, T15, D5, BULL, 25');
      return;
    }

    setState(() {
      totalDartsThrown++;
      
      final currentPlayer = players[currentPlayerIndex];
      
      // Check if hit affects current player's territory (to build up to killer status)
      if (KillerGameUtils.hitAffectsTerritory(hit, currentPlayer.territory)) {
        final hitCount = currentPlayer.hitCount + KillerGameUtils.calculateHitCount(hit);
        
        // Players gain health when hitting their own territory
        // Must have exactly 3 health to become a killer
        final newHealth = currentPlayer.health + KillerGameUtils.calculateHitCount(hit);
        final isKiller = newHealth >= 3;
        
        players[currentPlayerIndex] = currentPlayer.copyWith(
          hitCount: hitCount,
          health: newHealth,
          isKiller: isKiller,
        );
        
        if (isKiller && !currentPlayer.isKiller) {
          _showOverlayAnimation(GameOverlayType.playerBecomesKiller, currentPlayer.name);
        }
      }
      
      // If current player is a killer, check if they hit other players' territories
      if (players[currentPlayerIndex].isKiller) {
        for (int i = 0; i < players.length; i++) {
          if (i == currentPlayerIndex) continue; // Skip self
          
          final targetPlayer = players[i];
          if (targetPlayer.isEliminated) continue; // Skip eliminated players
          
          if (KillerGameUtils.hitAffectsTerritory(hit, targetPlayer.territory)) {
            final damageDealt = KillerGameUtils.calculateHitCount(hit);
            // Health can go negative, eliminated when health < 0
            final newHealth = targetPlayer.health - damageDealt;
            
            // If player loses health and was a killer, they lose killer status
            final isStillKiller = newHealth >= 3;
            
            players[i] = targetPlayer.copyWith(
              health: newHealth,
              isKiller: isStillKiller,
            );
            
            // Show feedback for elimination
            if (newHealth < 0) {
              _showOverlayAnimation(GameOverlayType.killerEliminated, targetPlayer.name);
            }
            // Note: No overlay for losing killer status per user request
            break; // Only one player can be hit per dart
          }
        }
      }
      
      // Check win condition - only non-eliminated players remain
      final activePlayers = players.where((p) => !p.isEliminated).toList();
      if (activePlayers.length <= 1) {
        _completeGame(activePlayers.isNotEmpty ? activePlayers.first.name : 'No winner');
      }
      // Note: We don't automatically move to next player here anymore - controlled by turn completion
    });

    // Clear input and save state
    _scoreController.clear();
    _saveGameState();
    _updateGameHistory();
  }

  /// Move to the next active player
  void _nextPlayer() {
    int nextIndex = currentPlayerIndex;
    do {
      nextIndex = (nextIndex + 1) % players.length;
    } while (players[nextIndex].isEliminated && nextIndex != currentPlayerIndex);
    
    currentPlayerIndex = nextIndex;
  }

  /// Complete the game
  void _completeGame(String winnerName) {
    setState(() {
      isGameCompleted = true;
      winner = winnerName;
    });
    
    // Save to history
    _saveToHistory(winnerName);
    
    KillerGameStateService.markGameCompleted();
    _showWinnerDialog(winnerName);
  }

  /// Save completed game to history
  Future<void> _saveToHistory(String winnerName) async {
    if (gameStartTime == null) return;

    try {
      final gameHistory = KillerGameHistory.fromGameData(
        gameStartTime: gameStartTime!,
        players: players,
        winner: winnerName,
        totalDartsThrown: totalDartsThrown,
      );

      await KillerGameHistoryService.saveGameToHistory(gameHistory);
    } catch (e) {
      debugPrint('Error saving Killer game to history: $e');
    }
  }

  /// Save current game state
  Future<void> _saveGameState() async {
    if (gameStartTime == null) return;
    
    final gameState = KillerGameState(
      players: players,
      currentPlayerIndex: currentPlayerIndex,
      gameStartTime: gameStartTime!,
      totalDartsThrown: totalDartsThrown,
      isCompleted: isGameCompleted,
      winner: winner,
    );

    await KillerGameStateService.saveGameState(gameState);
  }

  /// Create initial game history entry
  Future<void> _createGameHistory() async {
    // History will be continuously updated as the game progresses
    // For now, we just ensure the game state is saved
    await _saveGameState();
  }

  /// Update game history after each dart
  Future<void> _updateGameHistory() async {
    // Update the game state which serves as our ongoing history
    await _saveGameState();
  }

  /// Show dialog asking if user wants to resume existing game
  Future<bool> _showResumeDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Resume Game?'),
        content: const Text('You have an unfinished Killer game. Would you like to resume it or start a new one?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('New Game'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Start a completely new game
  Future<void> _startNewGame() async {
    // Set up player order
    List<String> orderedNames = List.from(widget.playerNames);
    if (widget.randomOrder) {
      orderedNames.shuffle();
    }

    // Generate random territories
    final territories = KillerGameUtils.getRandomTerritories(orderedNames.length);

    // Create players with assigned territories and colors
    players = orderedNames.asMap().entries.map((entry) {
      final index = entry.key;
      final name = entry.value;
      return KillerPlayer(
        name: name,
        territory: territories[index],
        health: 0, // Start at 0, work up to 3 to become killer
        isKiller: false,
        hitCount: 0,
      );
    }).toList();

    currentPlayerIndex = 0;
    gameStartTime = DateTime.now();
    totalDartsThrown = 0;
    isGameCompleted = false;
    winner = null;

    // Create initial game history entry
    await _createGameHistory();

    // Save initial game state
    await _saveGameState();
  }

  /// Get current player territories for dartboard visualization
  List<KillerPlayerTerritory> _getKillerTerritories() {
    return players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      final color = KillerGameUtils.getPlayerColor(index);
      
      // Health-based visual feedback
      double highlightOpacity = 0.3; // Base opacity
      double fillPercentage = 0.0;
      double pulseIntensity = 0.0;
      bool borderOnly = false;
      
      if (player.isEliminated) {
        // Eliminated players: very dark
        highlightOpacity = 0.2;
        fillPercentage = 0.0;
        borderOnly = true;
      } else {
        // Health progression: 1HP = 33%, 2HP = 66%, 3HP = 100%
        fillPercentage = (player.health / 3.0).clamp(0.0, 1.0);
        highlightOpacity = 0.3 + (fillPercentage * 0.4); // Gradually brighten
        
        if (player.isKiller) {
          // Killers: full brightness with pulse
          highlightOpacity = 0.8;
          pulseIntensity = index == currentPlayerIndex ? 0.4 : 0.2; // Current killer pulses more
        }
      }
      
      return KillerPlayerTerritory(
        playerName: player.name,
        areas: KillerGameUtils.territoryToStringSet(player.territory),
        playerColor: color,
        highlightOpacity: highlightOpacity,
        isEliminated: player.isEliminated,
        isKiller: player.isKiller,
        isCurrentPlayer: index == currentPlayerIndex,
        borderOnly: borderOnly,
        fillPercentage: fillPercentage,
        pulseIntensity: pulseIntensity,
        showPlayerName: true,
      );
    }).toList();
  }

  /// Show overlay animation for game events
  void _showOverlayAnimation(GameOverlayType type, String playerName) {
    setState(() {
      _overlayType = type;
      _overlayPlayerName = playerName;
      _showOverlay = true;
    });
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show winner dialog
  void _showWinnerDialog(String winnerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Game Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$winnerName Wins!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Total darts thrown: $totalDartsThrown'),
            if (gameStartTime != null)
              Text('Game duration: ${DateTime.now().difference(gameStartTime!).inMinutes} minutes'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              
              // Start a new game with same players
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => KillerGameScreen(
                    playerNames: widget.playerNames,
                    randomOrder: widget.randomOrder,
                  ),
                ),
              );
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).popUntil((r) => r.isFirst); // Return to home screen
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPlayer = players.isNotEmpty ? players[currentPlayerIndex] : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Killer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main game content
            _buildGameContent(context, currentPlayer),
            
            // Overlay animation
            GameOverlayAnimation(
              overlayType: _overlayType ?? GameOverlayType.killerTurnChange,
              playerName: _overlayPlayerName,
              isVisible: _showOverlay,
              onAnimationComplete: () {
                setState(() {
                  _showOverlay = false;
                });
              },
              onTapToClose: () {
                setState(() {
                  _showOverlay = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameContent(BuildContext context, KillerPlayer? currentPlayer) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final dartboardSize = isTablet ? 350.0 : 280.0;

    return Column(
      children: [
        // Dartboard section - responsive sizing
        Expanded(
          flex: isTablet ? 5 : 6,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Center(
              child: SizedBox(
                width: dartboardSize,
                height: dartboardSize,
                child: InteractiveDartboard(
                  size: dartboardSize,
                  killerTerritories: _getKillerTerritories(),
                  interactive: false, // Pure visual now
                ),
              ),
            ),
          ),
        ),
        
        // Combined current player and dart tracking section
        if (currentPlayer != null && !isGameCompleted)
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 16,
              vertical: isTablet ? 12 : 8,
            ),
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Current player name
                Text(
                  '${currentPlayer.name}\'s Turn',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: isTablet ? 26 : 22,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: isTablet ? 16 : 12),
                
                // Dart tracking display with dart icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Darts: ',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: isTablet ? 18 : 16,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    ...List.generate(_maxDartsPerTurn, (index) {
                      if (index < _currentTurnDarts.length) {
                        // Show result of thrown dart
                        final dart = _currentTurnDarts[index];
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: isTablet ? 4 : 3),
                          child: Container(
                            width: isTablet ? 44 : 36,
                            height: isTablet ? 44 : 36,
                            decoration: BoxDecoration(
                              color: dart.isMiss 
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : dart.playerColor?.withOpacity(0.8),
                              border: Border.all(
                                color: dart.isMiss 
                                    ? Theme.of(context).colorScheme.error
                                    : dart.playerColor!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                dart.isMiss 
                                    ? 'M' 
                                    : dart.playerTarget.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: dart.isMiss 
                                      ? Theme.of(context).colorScheme.onErrorContainer
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Show remaining dart icon using SVG
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: isTablet ? 4 : 3),
                          child: DartIcon(
                            size: isTablet ? 44 : 36,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                          ),
                        );
                      }
                    }),
                  ],
                ),
              ],
            ),
          ),

        // Control buttons section - responsive sizing
        Expanded(
          flex: isTablet ? 4 : 4,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Column(
              children: [
                // Multiplier buttons row with strong theme colors
                SizedBox(
                  height: isTablet ? 60 : 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMultiplierButton(2, isTablet),
                      ),
                      SizedBox(width: isTablet ? 16 : 12),
                      Expanded(
                        child: _buildMultiplierButton(3, isTablet),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: isTablet ? 20 : 16),
                
                // Player/Target buttons - only show enabled ones
                Expanded(
                  child: _buildPlayerButtons(isTablet),
                ),
                
                SizedBox(height: isTablet ? 20 : 16),
                
                // Action buttons row with strong theme colors
                SizedBox(
                  height: isTablet ? 60 : 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                            padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 14),
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                            ),
                          ),
                          onPressed: isGameCompleted ? null : () => _handleMissTap(),
                          icon: Icon(Icons.close, size: isTablet ? 24 : 20),
                          label: Text(
                            'Miss',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 18 : 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isTablet ? 16 : 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                            padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 14),
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                            ),
                          ),
                          onPressed: (isGameCompleted || _currentTurnDarts.isEmpty) ? null : () => _handleUndoTap(),
                          icon: Icon(Icons.undo, size: isTablet ? 24 : 20),
                          label: Text(
                            'Undo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 18 : 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplierButton(int multiplier, bool isTablet) {
    final isSelected = _selectedMultiplier == multiplier;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onPrimaryContainer,
          elevation: isSelected ? 8 : 2,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
          ),
        ),
        onPressed: isGameCompleted ? null : () => _handleMultiplierTap(multiplier),
        child: Text(
          'x$multiplier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 20 : 18,
          ),
        ),
      ),
    );
  }

  // Button handlers for new UI
  void _handleMultiplierTap(int multiplier) {
    setState(() {
      _selectedMultiplier = multiplier;
    });
  }

  void _handlePlayerButtonTap(String playerName) async {
    // Don't allow more than 3 darts per turn
    if (_currentTurnDarts.length >= _maxDartsPerTurn) return;
    
    // Haptic feedback for successful button press
    HapticFeedback.lightImpact();
    
    // Construct the dart hit based on the target player and current multiplier
    final targetPlayer = players.firstWhere((p) => p.name == playerName);
    final targetPlayerIndex = players.indexWhere((p) => p.name == playerName);
    final targetColor = KillerGameUtils.getPlayerColor(targetPlayerIndex);
    
    // Determine which territory number to hit
    final targetNumber = targetPlayer.territory.first;
    
    String dartScore;
    if (_selectedMultiplier == 1) {
      dartScore = targetNumber.toString();
    } else if (_selectedMultiplier == 2) {
      dartScore = 'D$targetNumber';
    } else {
      dartScore = 'T$targetNumber';
    }
    
    // Add to dart tracking
    setState(() {
      _currentTurnDarts.add(DartResult.hit(playerName, _selectedMultiplier, targetColor));
    });
    
    // Process the dart
    _processDart(dartScore);
    
    // Reset multiplier to 1 after use
    setState(() {
      _selectedMultiplier = 1;
    });
    
    // Check if turn is complete (3 darts or game ended)
    if (_currentTurnDarts.length >= _maxDartsPerTurn || isGameCompleted) {
      _completeTurn();
    }
  }

  void _handleMissTap() {
    // Don't allow more than 3 darts per turn
    if (_currentTurnDarts.length >= _maxDartsPerTurn) return;
    
    // Add to dart tracking
    setState(() {
      _currentTurnDarts.add(DartResult.miss());
    });
    
    // Process a miss (score 0)
    _processMiss();
    
    // Reset multiplier
    setState(() {
      _selectedMultiplier = 1;
    });
    
    // Check if turn is complete
    if (_currentTurnDarts.length >= _maxDartsPerTurn) {
      _completeTurn();
    }
  }

  void _handleUndoTap() {
    // Simple undo: if there are darts in current turn, remove the last one
    if (_currentTurnDarts.isNotEmpty) {
      setState(() {
        _currentTurnDarts.removeLast();
        if (totalDartsThrown > 0) {
          totalDartsThrown--;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Last dart undone'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Update history
      _updateGameHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No darts to undo this turn'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Process a miss (no score)
  void _processMiss() async {
    setState(() {
      totalDartsThrown++;
    });

    // Save state and update history
    await _saveGameState();
    await _updateGameHistory();
  }

  /// Complete the current turn and move to next player
  void _completeTurn() {
    setState(() {
      _currentTurnDarts.clear();
      if (!isGameCompleted) {
        final previousPlayerIndex = currentPlayerIndex;
        _nextPlayer();
        
        // Show turn change overlay if player actually changed
        if (currentPlayerIndex != previousPlayerIndex) {
          final nextPlayer = players[currentPlayerIndex];
          _showOverlayAnimation(GameOverlayType.killerTurnChange, nextPlayer.name);
        }
      }
    });
  }

  /// Build player buttons - only show enabled ones with smart layout
  Widget _buildPlayerButtons([bool isTablet = false]) {
    final currentPlayer = players[currentPlayerIndex];
    List<Widget> enabledButtons = [];
    
    for (int index = 0; index < players.length; index++) {
      final player = players[index];
      final color = KillerGameUtils.getPlayerColor(index);
      
      // Smart button enabling logic
      bool isEnabled = false;
      
      if (isGameCompleted || player.isEliminated) {
        // Skip game over or player eliminated
        continue;
      } else if (index == currentPlayerIndex) {
        // Current player's own button
        if (!currentPlayer.isKiller) {
          // Non-killers can hit their own territory
          isEnabled = true;
        } else {
          // Killers cannot hit themselves - skip
          continue;
        }
      } else {
        // Other player's button
        if (currentPlayer.isKiller) {
          // Killers can target other players
          isEnabled = true;
        } else {
          // Non-killers cannot target others - skip
          continue;
        }
      }
      
      if (isEnabled) {
        // Create status indicators
        List<Widget> statusIndicators = [];
        
        // Health indicators
        for (int i = 0; i < 3; i++) {
          statusIndicators.add(
            Container(
              width: isTablet ? 8 : 6,
              height: isTablet ? 8 : 6,
              margin: EdgeInsets.symmetric(horizontal: isTablet ? 1.5 : 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < player.health 
                    ? Colors.white.withOpacity(0.9)
                    : Colors.white.withOpacity(0.3),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
          );
        }
        
        enabledButtons.add(
          Container(
            margin: EdgeInsets.all(isTablet ? 4 : 3),
            child: Material(
              elevation: player.isKiller ? 12 : 8,
              shadowColor: color.withOpacity(0.6),
              borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                onTap: () => _handlePlayerButtonTap(player.name),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                    border: player.isKiller ? Border.all(
                      color: Colors.white,
                      width: 2,
                    ) : null,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : 14,
                    horizontal: isTablet ? 20 : 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Player name
                      Text(
                        player.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: player.isKiller ? FontWeight.w900 : FontWeight.bold,
                          fontSize: isTablet ? 16 : 14,
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: isTablet ? 6 : 4),
                      
                      // Health indicators
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: statusIndicators,
                      ),
                      
                      // Killer indicator
                      if (player.isKiller) ...[
                        SizedBox(height: isTablet ? 4 : 3),
                        Text(
                          'KILLER',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 10 : 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    
    // If no buttons are enabled, show a message
    if (enabledButtons.isEmpty) {
      return Center(
        child: Text(
          'No targets available',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }
    
    // Smart layout based on number of buttons and screen size
    return _buildSmartButtonLayout(enabledButtons, isTablet);
  }
  
  /// Build smart button layout that adapts to player count and screen size
  Widget _buildSmartButtonLayout(List<Widget> buttons, bool isTablet) {
    final buttonCount = buttons.length;
    
    // For 2-3 players: single row
    if (buttonCount <= 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons.map((button) => Expanded(
          child: button,
        )).toList(),
      );
    }
    
    // For 4+ players: use a grid layout
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal columns based on available width and button count
        int columns = 2;
        if (buttonCount == 4) {
          columns = 2; // 2x2 grid
        } else if (buttonCount == 5) {
          columns = isTablet ? 3 : 2; // 3x2 or 2x3 depending on space
        } else if (buttonCount >= 6) {
          columns = isTablet ? 3 : 2; // 3x2 or 2x3
        }
        
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isTablet ? 2.2 : 2.0,
          mainAxisSpacing: isTablet ? 8 : 6,
          crossAxisSpacing: isTablet ? 8 : 6,
          children: buttons,
        );
      },
    );
  }
}

/// Represents the result of a single dart throw for display purposes
class DartResult {

  const DartResult({
    required this.playerTarget,
    required this.multiplier,
    required this.isHit,
    required this.isMiss,
    this.playerColor,
  });

  /// Creates a dart result for a hit
  factory DartResult.hit(String playerTarget, int multiplier, Color playerColor) {
    return DartResult(
      playerTarget: playerTarget,
      multiplier: multiplier,
      isHit: true,
      isMiss: false,
      playerColor: playerColor,
    );
  }

  /// Creates a dart result for a miss
  factory DartResult.miss() {
    return const DartResult(
      playerTarget: '',
      multiplier: 1,
      isHit: false,
      isMiss: true,
    );
  }
  final String playerTarget;
  final int multiplier;
  final bool isHit;
  final bool isMiss;
  final Color? playerColor;
}
