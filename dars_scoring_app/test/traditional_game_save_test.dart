import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/models/app_enums.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';

void main() {
  group('Traditional Game Save/Load Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test and set animation speed to none
      SharedPreferences.setMockInitialValues({
        'animationSpeed': AnimationSpeed.none.index,
      });
    });    test('should save and load a new traditional game', () async {
      // Create a new traditional game
      final players = ['Alice', 'Bob'];
      final controller = TraditionalGameController(
        startingScore: 501,
        players: players,
      );
      
      // Score to trigger save (games only save when there are throws)
      await controller.score(20, '20');
      // Wait for the debounced save to complete
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Load from SharedPreferences directly to verify
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      
      expect(games.length, 1);
      
      // Parse the saved game
      final gameData = gameFromJson(games.first);
      expect(gameData.players, equals(players));
      expect(gameData.gameMode, 501);
      expect(gameData.completedAt, isNull);
      
      controller.dispose();
    });    test('should save game state after scoring', () async {
      final players = ['Alice', 'Bob'];
      final controller = TraditionalGameController(
        startingScore: 501,
        players: players,
      );
      
      // Score some points
      await controller.score(20, '20'); // Alice scores 20
      await controller.score(20, '20'); // Alice scores another 20
      await controller.score(17, '17'); // Alice scores 17, turn ends
      // Wait for debounced save
      await Future.delayed(const Duration(milliseconds: 600));      // Load the game from storage
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      expect(games.length, 1);
      
      final gameData = gameFromJson(games.first);
      expect(gameData.throws.length, 3);
      expect(controller.scoreFor('Alice'), 501 - 57); // 501 - (20+20+17)
      expect(gameData.currentPlayer, 1); // Should be Bob's turn
      
      controller.dispose();
    });

    test('should maintain current player and darts thrown state', () async {
      final players = ['Alice', 'Bob', 'Charlie'];
      final controller = TraditionalGameController(
        startingScore: 301,
        players: players,
      );
      
      // Alice throws 2 darts
      await controller.score(20, '20');      await controller.score(19, '19');
      
      // Wait for save
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Load game and check state
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      final gameData = gameFromJson(games.first);
      
      expect(gameData.currentPlayer, 0); // Still Alice's turn
      expect(gameData.dartsThrown, 2);
      
      controller.dispose();
    });

    test('should save completed game with winner', () async {
      final players = ['Alice', 'Bob'];
      final controller = TraditionalGameController(
        startingScore: 50, // Small score for quick finish
        players: players,
        checkoutRule: CheckoutRule.exactOut, // Easy finish rule
      );
      
      // Alice wins with exact finish
      await controller.score(50, 'Bull');
      
      // Wait for save
      await Future.delayed(const Duration(milliseconds: 100));
      
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      final gameData = gameFromJson(games.first);
      
      expect(gameData.winner, 'Alice');
      expect(gameData.completedAt, isNotNull);
      
      controller.dispose();
    });    test('should handle bust and save correctly', () async {
      final players = ['Alice', 'Bob'];
      final controller = TraditionalGameController(
        startingScore: 51, // Changed to 51 to create a proper bust scenario
        players: players,
        checkoutRule: CheckoutRule.doubleOut,
      );
      
      // Alice tries to finish but busts (hits single 50, leaving 1 point)
      await controller.score(50, 'Bull');
      
      // Wait for bust timer and turn change
      await Future.delayed(const Duration(milliseconds: 5000)); // Increased to wait for both bust and turn change timers
        // Check that bust was handled correctly
      expect(controller.scoreFor('Alice'), 51); // Score should be reset to turn start
      expect(controller.currentPlayer, 1); // Should be Bob's turn        // Wait for save
      await Future.delayed(const Duration(milliseconds: 700));
      
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      print('TEST: Found ${games.length} games in SharedPreferences');
      print('TEST: Games keys: ${prefs.getKeys()}');
      expect(games.length, 1);
      
      final gameData = gameFromJson(games.first);
      
      expect(gameData.throws.length, 1);
      expect(gameData.throws.first.wasBust, true);
      
      controller.dispose();
    });

    test('should resume game from saved state', () async {
      // Create and partially play a game
      final players = ['Alice', 'Bob'];
      final controller1 = TraditionalGameController(
        startingScore: 301,
        players: players,
      );
      
      await controller1.score(20, '20'); // Alice hits 20
      await controller1.score(20, '20'); // Alice hits 20 again
      await controller1.score(19, '19'); // Alice hits 19, turn ends
      // Bob's turn now
      await controller1.score(25, '25'); // Bob hits 25
      
      await Future.delayed(const Duration(milliseconds: 600)); // Wait for save
      
      // Get the saved game
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      final savedGame = gameFromJson(games.first);
      
      controller1.dispose();
      
      // Resume with a new controller
      final controller2 = TraditionalGameController(
        startingScore: 301,
        players: players,
        resumeGame: savedGame,
      );
      
      // Check that state was properly restored
      expect(controller2.currentPlayer, 1); // Bob's turn
      expect(controller2.dartsThrown, 1); // Bob has thrown 1 dart
      expect(controller2.scoreFor('Alice'), 301 - 59); // 301 - (20+20+19)
      expect(controller2.scoreFor('Bob'), 301 - 25); // 301 - 25
      
      controller2.dispose();
    });

    test('should handle undo and save correctly', () async {
      final players = ['Alice', 'Bob'];
      final controller = TraditionalGameController(
        startingScore: 301,
        players: players,
      );
      
      // Alice scores some points
      await controller.score(20, '20');
      await controller.score(20, '20');
      await controller.score(17, '17');
      
      // Undo the last throw
      await controller.undoLastThrow();
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Check that the undo was saved
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      final gameData = gameFromJson(games.first);
      
      expect(gameData.throws.length, 2);
      expect(controller.scoreFor('Alice'), 301 - 40); // Only 20+20, not 17
      
      controller.dispose();
    });

    test('should handle multiple games without conflicts', () async {
      // Create first game
      final controller1 = TraditionalGameController(
        startingScore: 501,
        players: ['Alice', 'Bob'],
      );      await controller1.score(20, '20');
      await Future.delayed(const Duration(milliseconds: 700));
      controller1.dispose();
      
      // Create second game
      final controller2 = TraditionalGameController(
        startingScore: 301,
        players: ['Charlie', 'Dave'],
      );
      await controller2.score(25, '25');
      await Future.delayed(const Duration(milliseconds: 700));
      controller2.dispose();
      
      // Verify both games are saved
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      expect(games.length, 2);
      
      // Parse both games and verify they're different
      final game1 = gameFromJson(games[0]);
      final game2 = gameFromJson(games[1]);
      
      expect(game1.gameMode, 501);
      expect(game2.gameMode, 301);
      expect(game1.players, ['Alice', 'Bob']);
      expect(game2.players, ['Charlie', 'Dave']);
    });

    test('should update existing game instead of creating duplicates', () async {
      final players = ['Alice', 'Bob'];
      final controller = TraditionalGameController(
        startingScore: 301,
        players: players,
      );
        // Score and save multiple times
      await controller.score(20, '20');
      await Future.delayed(const Duration(milliseconds: 700));
      
      await controller.score(19, '19');
      await Future.delayed(const Duration(milliseconds: 700));
      
      await controller.score(18, '18');
      await Future.delayed(const Duration(milliseconds: 4000)); // Wait longer for turn change
      
      // Should only have one game, not three
      final prefs = await SharedPreferences.getInstance();
      final games = prefs.getStringList('games_history') ?? [];
      expect(games.length, 1);
      
      final gameData = gameFromJson(games.first);
      expect(gameData.throws.length, 3);
      
      controller.dispose();
    });
  });
}

// Helper function to parse game JSON (matches what traditional game service does)
GameHistory gameFromJson(String jsonString) {
  return GameHistory.fromJson(Map<String, dynamic>.from(
    (jsonDecode(jsonString) as Map).cast<String, dynamic>()
  ));
}
