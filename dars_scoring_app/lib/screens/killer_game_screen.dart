import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/killer_player.dart';
import '../utils/killer_game_utils.dart';
import '../services/killer_game_state_service.dart';
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
      } else {
        // Move to next player
        _nextPlayer();
      }
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
    
    KillerGameStateService.markGameCompleted();
    _showWinnerDialog(winnerName);
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
      
      // FIXED: Visual feedback based on correct health system
      return KillerPlayerTerritory(
        playerName: player.name,
        areas: KillerGameUtils.territoryToStringSet(player.territory),
        playerColor: color,
        highlightOpacity: 0.6,
        isEliminated: player.isEliminated, // health < 0
        isKiller: player.isKiller, // health >= 3
        isCurrentPlayer: index == currentPlayerIndex,
        borderOnly: player.isEliminated, // Only border for eliminated players
        fillPercentage: player.isEliminated ? 0.0 : (player.health / 3.0).clamp(0.0, 1.0),
        pulseIntensity: index == currentPlayerIndex ? 0.5 : 0.0,
        showPlayerName: false,
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
        actions: [
          IconButton(
            onPressed: () => _showGameInfo(),
            icon: const Icon(Icons.info_outline),
          ),
          if (!isGameCompleted)
            IconButton(
              onPressed: () => _pauseGame(),
              icon: const Icon(Icons.pause),
            ),
        ],
      ),
      body: Column(
        children: [
          // Dartboard
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: InteractiveDartboard(
                size: 300,
                killerTerritories: _getKillerTerritories(),
                onAreaTapped: isGameCompleted ? null : (area) {
                  // Auto-fill score input when dartboard is tapped
                  _scoreController.text = area;
                },
                interactive: !isGameCompleted,
              ),
            ),
          ),
          
          // Player status
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Current player info
                  if (currentPlayer != null && !isGameCompleted)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Current Player: ${currentPlayer.name}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text('Territory: ${currentPlayer.territory.join(', ')}'),
                                Text('Health: ${currentPlayer.health}'),
                                Text('Status: ${_getPlayerStatus(currentPlayer)}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Player list
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Players',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: players.length,
                                itemBuilder: (context, index) {
                                  final player = players[index];
                                  final color = KillerGameUtils.getPlayerColor(index);
                                  final isCurrentTurn = index == currentPlayerIndex && !isGameCompleted;
                                  
                                  return ListTile(
                                    leading: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: isCurrentTurn ? Border.all(color: Colors.white, width: 3) : null,
                                      ),
                                    ),
                                    title: Text(
                                      player.name,
                                      style: TextStyle(
                                        fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
                                        color: player.isEliminated ? Colors.grey : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Territory: ${player.territory.join(', ')} | Health: ${player.health} | ${_getPlayerStatus(player)}',
                                      style: TextStyle(
                                        color: player.isEliminated ? Colors.grey : null,
                                      ),
                                    ),
                                    trailing: player.isEliminated 
                                        ? const Icon(Icons.close, color: Colors.red)
                                        : player.isKiller 
                                            ? const Icon(Icons.star, color: Colors.amber)
                                            : null,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Score input
          if (!isGameCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _scoreController,
                          focusNode: _scoreFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Enter dart score',
                            hintText: '20, T15, D5, BULL, 25',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: _processDart,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => _processDart(_scoreController.text),
                        child: const Text('Throw'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
