import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/killer_player.dart';
import '../models/killer_game_history.dart';
import '../utils/killer_game_utils.dart';
import '../services/killer_game_state_service.dart';
import '../services/killer_game_history_service.dart';
import '../widgets/interactive_dartboard.dart';

/// Main screen for playing Killer darts game
class KillerGameScreen extends StatefulWidget {
  final List<String> playerNames;
  final bool randomOrder;

  const KillerGameScreen({
    super.key,
    required this.playerNames,
    required this.randomOrder,
  });

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
  String? _pendingTargetPlayer;
  
  // Dart tracking state
  List<DartResult> _currentTurnDarts = [];
  final int _maxDartsPerTurn = 3;

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
  void _initializeGame() {
    setState(() {
      _isLoading = true;
    });

    try {
      // Set up player order
      List<String> orderedNames = List.from(widget.playerNames);
      if (widget.randomOrder) {
        orderedNames.shuffle();
      }

      // Generate random territories
      final territories = KillerGameUtils.getRandomTerritories(orderedNames.length);

      // Create players with assigned territories and colors
      // FIXED: Players start at 0 health and work UP to become killers
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

      // Save initial game state
      _saveGameState();
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
        
        // FIXED: Players gain health when hitting their own territory
        // Need 3+ health to become a killer
        final newHealth = currentPlayer.health + KillerGameUtils.calculateHitCount(hit);
        final isKiller = newHealth >= 3;
        
        players[currentPlayerIndex] = currentPlayer.copyWith(
          hitCount: hitCount,
          health: newHealth,
          isKiller: isKiller,
        );
        
        if (isKiller && !currentPlayer.isKiller) {
          _showKillerNotification(currentPlayer.name);
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
            // FIXED: Health can go negative, eliminated when health < 0
            final newHealth = targetPlayer.health - damageDealt;
            
            players[i] = targetPlayer.copyWith(health: newHealth);
            
            // Show damage feedback
            _showDamageNotification(targetPlayer.name, damageDealt, newHealth);
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

  /// Get current player territories for dartboard visualization
  List<KillerPlayerTerritory> _getKillerTerritories() {
    return players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      final color = KillerGameUtils.getPlayerColor(index);
      
      // Enhanced visual feedback for health progression
      double fillPercentage = 0.0;
      double highlightOpacity = 0.4;
      double pulseIntensity = 0.0;
      
      if (player.isEliminated) {
        // Eliminated players: no fill, just dark border
        fillPercentage = 0.0;
        highlightOpacity = 0.2;
      } else if (player.isKiller) {
        // Killers: full bright glow
        fillPercentage = 1.0;
        highlightOpacity = 0.8;
        pulseIntensity = index == currentPlayerIndex ? 0.3 : 0.1;
      } else {
        // Building health: gradual fill from 0 to 3
        fillPercentage = (player.health / 3.0).clamp(0.0, 1.0);
        highlightOpacity = 0.3 + (fillPercentage * 0.3); // More visible as health increases
        pulseIntensity = index == currentPlayerIndex ? 0.2 : 0.0;
      }
      
      return KillerPlayerTerritory(
        playerName: player.name,
        areas: KillerGameUtils.territoryToStringSet(player.territory),
        playerColor: color,
        highlightOpacity: highlightOpacity,
        isEliminated: player.isEliminated,
        isKiller: player.isKiller,
        isCurrentPlayer: index == currentPlayerIndex,
        borderOnly: player.isEliminated,
        fillPercentage: fillPercentage,
        pulseIntensity: pulseIntensity,
        showPlayerName: true, // Show player names on territories
      );
    }).toList();
  }

  /// Show killer achievement notification
  void _showKillerNotification(String playerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 $playerName becomes a KILLER!'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.amber,
      ),
    );
  }

  /// Show damage notification
  void _showDamageNotification(String playerName, int damage, int newHealth) {
    final isEliminated = newHealth < 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEliminated 
              ? '💀 $playerName is ELIMINATED! (Health: $newHealth)'
              : '$playerName takes $damage damage! Health: $newHealth'
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isEliminated ? Colors.red : Colors.orange,
      ),
    );
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
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to game modes
            },
            child: const Text('New Game'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
            child: const Text('View Results'),
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
      appBar: AppBar(
        title: const Text('Killer'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dartboard section - takes up top portion
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: InteractiveDartboard(
                      size: 300,
                      killerTerritories: _getKillerTerritories(),
                      interactive: false, // Pure visual now
                    ),
                  ),
                ),
              ),
            ),
            
            // Current player indicator
            if (currentPlayer != null && !isGameCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${currentPlayer.name}\'s Turn',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            
            // Dart tracking display
            if (!isGameCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Darts: ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(_maxDartsPerTurn, (index) {
                          if (index < _currentTurnDarts.length) {
                            // Show result of thrown dart
                            final dart = _currentTurnDarts[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: dart.isMiss 
                                      ? Colors.grey[300]
                                      : dart.playerColor?.withOpacity(0.7),
                                  border: Border.all(
                                    color: dart.isMiss 
                                        ? Colors.grey[600]! 
                                        : dart.playerColor!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    dart.isMiss 
                                        ? 'M' 
                                        : dart.playerTarget.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      color: dart.isMiss 
                                          ? Colors.grey[700] 
                                          : dart.playerColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // Show remaining dart icon
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                Icons.near_me,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                              ),
                            );
                          }
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Control buttons section - takes up bottom portion
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Multiplier buttons row with selection highlighting
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedMultiplier == 2 
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                                  : Theme.of(context).colorScheme.surface,
                              foregroundColor: _selectedMultiplier == 2
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              elevation: _selectedMultiplier == 2 ? 4 : 1,
                            ),
                            onPressed: isGameCompleted ? null : () => _handleMultiplierTap(2),
                            child: Text(
                              'x2',
                              style: TextStyle(
                                fontWeight: _selectedMultiplier == 2 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedMultiplier == 3 
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                                  : Theme.of(context).colorScheme.surface,
                              foregroundColor: _selectedMultiplier == 3
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              elevation: _selectedMultiplier == 3 ? 4 : 1,
                            ),
                            onPressed: isGameCompleted ? null : () => _handleMultiplierTap(3),
                            child: Text(
                              'x3',
                              style: TextStyle(
                                fontWeight: _selectedMultiplier == 3 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Player/Target buttons with smart enabling
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final player = players[index];
                          final color = KillerGameUtils.getPlayerColor(index);
                          final currentPlayer = players[currentPlayerIndex];
                          
                          // Smart button enabling logic
                          bool isEnabled = false;
                          String buttonText = player.name;
                          Color backgroundColor = color.withOpacity(0.2);
                          Color foregroundColor = color;
                          
                          if (isGameCompleted || player.isEliminated) {
                            // Game over or player eliminated
                            isEnabled = false;
                            backgroundColor = Colors.grey.withOpacity(0.1);
                            foregroundColor = Colors.grey;
                          } else if (index == currentPlayerIndex) {
                            // Current player's own button
                            if (!currentPlayer.isKiller) {
                              // Non-killers can hit their own territory
                              isEnabled = true;
                              backgroundColor = color.withOpacity(0.3);
                              buttonText = '${player.name} (${player.territory.join(', ')})';
                            } else {
                              // Killers cannot hit themselves
                              isEnabled = false;
                              backgroundColor = color.withOpacity(0.1);
                              foregroundColor = color.withOpacity(0.5);
                              buttonText = '${player.name} (Killer)';
                            }
                          } else {
                            // Other player's button
                            if (currentPlayer.isKiller) {
                              // Killers can target other players
                              isEnabled = true;
                              backgroundColor = color.withOpacity(0.3);
                              buttonText = '${player.name} (${player.territory.join(', ')})';
                            } else {
                              // Non-killers cannot target others
                              isEnabled = false;
                              backgroundColor = color.withOpacity(0.1);
                              foregroundColor = color.withOpacity(0.5);
                            }
                          }
                          
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: backgroundColor,
                              foregroundColor: foregroundColor,
                              side: BorderSide(color: color.withOpacity(isEnabled ? 1.0 : 0.3)),
                              elevation: isEnabled ? 2 : 0,
                            ),
                            onPressed: isEnabled ? () => _handlePlayerButtonTap(player.name) : null,
                            child: Text(
                              buttonText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Action buttons row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              foregroundColor: Colors.grey[700],
                            ),
                            onPressed: () => _handleMissTap(),
                            child: const Text('Miss'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              foregroundColor: Colors.orange[700],
                            ),
                            onPressed: () => _handleUndoTap(),
                            child: const Text('Undo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  void _handlePlayerButtonTap(String playerName) {
    // Don't allow more than 3 darts per turn
    if (_currentTurnDarts.length >= _maxDartsPerTurn) return;
    
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
    // TODO: Implement undo logic in Phase 4
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Undo functionality coming in Phase 4'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Process a miss (no score)
  void _processMiss() {
    setState(() {
      totalDartsThrown++;
    });

    // Save state but don't automatically move to next player
    _saveGameState();
  }

  /// Complete the current turn and move to next player
  void _completeTurn() {
    setState(() {
      _currentTurnDarts.clear();
      if (!isGameCompleted) {
        _nextPlayer();
      }
    });
  }

  /// Get player status description
  String _getPlayerStatus(KillerPlayer player) {
    if (player.isEliminated) {
      return 'ELIMINATED';
    } else if (player.isKiller) {
      return 'KILLER';
    } else {
      return 'Building (${player.health}/3)';
    }
  }

  /// Show game information dialog
  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Rules'),
        content: const SingleChildScrollView(
          child: Text(
            'KILLER DARTS RULES:\n\n'
            '• Each player gets 3 random consecutive numbers as territory\n'
            '• Players start at 0 health and work UP\n'
            '• Hit your territory to gain health (3+ = KILLER)\n'
            '• Killers can eliminate others by hitting their territories\n'
            '• Multipliers count: Double = 2 hits, Triple = 3 hits\n'
            '• Players are eliminated when health goes negative\n'
            '• Last surviving player wins!\n\n'
            'SCORING:\n'
            '• Single numbers: 1-20\n'
            '• Doubles: D1-D20\n'
            '• Triples: T1-T20\n'
            '• Bull: BULL (50 points)\n'
            '• Outer Bull: 25\n',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  /// Pause game (save state and return to menu)
  void _pauseGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause Game'),
        content: const Text('Game will be saved. You can resume later from the main menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _saveGameState();
              if (mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to main menu
              }
            },
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }
}

/// Represents the result of a single dart throw for display purposes
class DartResult {
  final String playerTarget;
  final int multiplier;
  final bool isHit;
  final bool isMiss;
  final Color? playerColor;

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
}
