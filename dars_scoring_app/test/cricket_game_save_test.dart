import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/services/cricket_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Cricket Game Save/Load Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });    test('should save and load a new cricket game', () async {
      // Create a new cricket game
      final players = ['Alice', 'Bob'];
      final controller = CricketGameController(players: players);
      
      // Initialize and save the new game
      await controller.initializeNewGame();
      
      // Load all saved games
      final savedGames = await CricketGameController.getAllSavedGames();
      
      expect(savedGames.length, 1);
      expect(savedGames.first.players, equals(players));
      expect(savedGames.first.gameMode, 'Cricket');
      expect(savedGames.first.completedAt, isNull);
      
      controller.dispose();
    });    test('should save game state after scoring', () async {
      final players = ['Alice', 'Bob'];
      final controller = CricketGameController(players: players);
      
      // Initialize the game first
      await controller.initializeNewGame();
      
      // Score some points
      await controller.score(20); // Alice hits single 20
      await controller.score(20); // Alice hits another single 20
      await controller.score(20); // Alice closes 20
      
      // Wait for debounced save
      await Future.delayed(Duration(milliseconds: 600));
      
      // Load the game from storage
      final savedGames = await CricketGameController.getAllSavedGames();
      expect(savedGames.length, 1);
      
      final savedGame = savedGames.first;
      expect(savedGame.throws.length, 3);
      expect(savedGame.playerStates['Alice']!.hits[20], 3);
      expect(savedGame.playerStates['Alice']!.isNumberClosed(20), true);
      
      controller.dispose();
    });    test('should maintain current player and darts thrown state', () async {
      final players = ['Alice', 'Bob', 'Charlie'];
      final controller = CricketGameController(players: players);
      
      // Initialize the game first
      await controller.initializeNewGame();
      
      // Alice throws 2 darts
      await controller.score(20);
      await controller.score(19);
      
      // Wait for save
      await Future.delayed(Duration(milliseconds: 600));
      
      // Load game and check state
      final savedGames = await CricketGameController.getAllSavedGames();
      final savedGame = savedGames.first;
      
      expect(savedGame.currentPlayer, 0); // Still Alice's turn
      expect(savedGame.dartsThrown, 2);
      
      controller.dispose();
    });    test('should save completed game with winner', () async {
      final players = ['Alice', 'Bob'];
      final controller = CricketGameController(players: players);
      
      // Initialize the game first
      await controller.initializeNewGame();
      
      // Alice closes all numbers to win
      for (final number in CricketGameController.cricketNumbers) {
        for (int i = 0; i < 3; i++) {
          await controller.score(number);
        }
      }
      
      // Wait for save
      await Future.delayed(Duration(milliseconds: 100));
      
      final savedGames = await CricketGameController.getAllSavedGames();
      final savedGame = savedGames.first;
      
      expect(savedGame.winner, 'Alice');
      expect(savedGame.completedAt, isNotNull);
      
      controller.dispose();
    });    test('should filter unfinished games correctly', () async {
      // Create and complete one game
      final controller1 = CricketGameController(players: ['Alice', 'Bob']);
      await controller1.initializeNewGame();
      for (final number in CricketGameController.cricketNumbers) {
        for (int i = 0; i < 3; i++) {
          await controller1.score(number);
        }
      }
      await Future.delayed(Duration(milliseconds: 100));
      controller1.dispose();
      
      // Create an unfinished game
      final controller2 = CricketGameController(players: ['Charlie', 'Dave']);
      await controller2.initializeNewGame();
      await controller2.score(20);
      await Future.delayed(Duration(milliseconds: 600));
      controller2.dispose();
      
      // Check that we get only the unfinished game
      final unfinishedGames = await CricketGameController.getUnfinishedGames();
      expect(unfinishedGames.length, 1);
      expect(unfinishedGames.first.players, ['Charlie', 'Dave']);
      expect(unfinishedGames.first.winner, isNull);
    });    test('should resume game from saved state', () async {
      // Create and partially play a game
      final players = ['Alice', 'Bob'];
      final controller1 = CricketGameController(players: players);
      
      await controller1.initializeNewGame();
      await controller1.score(20); // Alice hits 20
      await controller1.score(20); // Alice hits 20 again
      await controller1.score(19); // Alice hits 19, turn ends
        // Bob's turn now
      await controller1.score(20); // Bob hits 20
      
      // Wait for turn change animation and saves
      await Future.delayed(Duration(milliseconds: 2500));
      final gameId = controller1.currentGame.id;
      controller1.dispose();
      
      // Load the saved game
      final savedGame = await CricketGameController.loadGame(gameId);
      expect(savedGame, isNotNull);
      
      // Resume with a new controller
      final controller2 = CricketGameController(
        players: players,
        resumeGame: savedGame,
      );
      
      // Check that state was properly restored
      expect(controller2.currentPlayer, 1); // Bob's turn
      expect(controller2.dartsThrown, 1); // Bob has thrown 1 dart
      expect(controller2.getPlayerState('Alice').hits[20], 2);
      expect(controller2.getPlayerState('Alice').hits[19], 1);
      expect(controller2.getPlayerState('Bob').hits[20], 1);
      
      controller2.dispose();
    });    test('should handle undo and save correctly', () async {
      final players = ['Alice', 'Bob'];
      final controller = CricketGameController(players: players);
      
      await controller.initializeNewGame();
      
      // Alice scores 3x20 to close it
      await controller.score(20);
      await controller.score(20);
      await controller.score(20);
      
      // Undo the last throw
      await controller.undoLastThrow();
      
      await Future.delayed(Duration(milliseconds: 600));
      
      // Check that the undo was saved
      final savedGames = await CricketGameController.getAllSavedGames();
      final savedGame = savedGames.first;
      
      expect(savedGame.throws.length, 2);
      expect(savedGame.playerStates['Alice']!.hits[20], 2);
      expect(savedGame.playerStates['Alice']!.isNumberClosed(20), false);
      
      controller.dispose();
    });    test('should delete games correctly', () async {
      // Create two games
      final controller1 = CricketGameController(players: ['Alice', 'Bob']);
      await controller1.initializeNewGame();
      await Future.delayed(Duration(milliseconds: 100));
      final gameId1 = controller1.currentGame.id;
      controller1.dispose();
      
      final controller2 = CricketGameController(players: ['Charlie', 'Dave']);
      await controller2.initializeNewGame();
      await Future.delayed(Duration(milliseconds: 100));
      final gameId2 = controller2.currentGame.id;
      controller2.dispose();
      
      // Verify both games exist
      final allGames = await CricketGameController.getAllSavedGames();
      expect(allGames.length, 2);
      
      // Delete one game
      final deleted = await CricketGameController.deleteGame(gameId1);
      expect(deleted, true);
      
      // Verify only one game remains
      final remainingGames = await CricketGameController.getAllSavedGames();
      expect(remainingGames.length, 1);
      expect(remainingGames.first.id, gameId2);
    });    test('should handle miss scoring and save', () async {
      final players = ['Alice', 'Bob'];
      final controller = CricketGameController(players: players);
      
      // Alice throws a miss
      await controller.scoreMiss();
      await controller.scoreMiss();
      await controller.scoreMiss();
      
      // Wait for turn change animation (2 seconds + buffer)
      await Future.delayed(Duration(milliseconds: 2500));
        // Check that misses were saved
      final savedGames = await CricketGameController.getAllSavedGames();
      final savedGame = savedGames.first;
      
      expect(savedGame.throws.length, 3);
      expect(savedGame.throws.every((t) => t.value == 0), true);
      expect(savedGame.currentPlayer, 1); // Should be Bob's turn now
      
      controller.dispose();
    });
  });
}
