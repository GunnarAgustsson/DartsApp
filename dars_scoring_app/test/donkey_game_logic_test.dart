import 'package:flutter_test/flutter_test.dart';
import 'package:dars_scoring_app/models/donkey_game.dart';
import 'package:dars_scoring_app/models/app_enums.dart';
import 'package:dars_scoring_app/services/donkey_game_service.dart';

void main() {
  group('Donkey Game Logic Tests', () {
    late DonkeyGameController controller;    setUpAll(() async {
      // Initialize Flutter binding for SharedPreferences
      TestWidgetsFlutterBinding.ensureInitialized();
    });    setUp(() async {
      controller = DonkeyGameController(
        players: ['Alice', 'Bob', 'Charlie'],
        variant: DonkeyVariant.oneDart,
        isTest: true, // This will prevent SharedPreferences calls
      );
      // Wait for async initialization to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      controller.dispose();
    });

    test('should initialize with correct players and variant', () {
      expect(controller.players.length, 3);
      expect(controller.variant, DonkeyVariant.oneDart);
      expect(controller.currentTarget, 0);
      expect(controller.dartsThrown, 0);
    });

    test('should set target on first turn', () {
      // First player scores 20
      controller.score(20);
      
      expect(controller.currentTarget, 20);
      expect(controller.targetSetBy, 'Alice');
    });    test('should give letter for failing to beat target', () async {
      // Alice sets target
      controller.score(20);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check Alice's state  
      final aliceState = controller.getPlayerState('Alice');
      expect(aliceState.letters, '');
      expect(controller.currentTarget, 20);
      
      // Bob fails to beat 20
      controller.score(15);
      await Future.delayed(const Duration(milliseconds: 500));
      
      final bobState = controller.getPlayerState('Bob');
      expect(bobState.letters.length, 1);
      expect(bobState.letters, 'D');
    });

    test('should handle player elimination correctly', () {
      final alice = controller.getPlayerState('Alice');
      
      // Add letters one by one
      var updatedAlice = alice;
      for (int i = 0; i < 6; i++) {
        updatedAlice = updatedAlice.addLetter();
      }
      
      expect(updatedAlice.letters, 'DONKEY');
      expect(updatedAlice.isEliminated, true);
    });

    test('should format letters correctly for display', () {
      // Create a player with some letters
      final playerState = DonkeyPlayerState(name: 'Test', letters: 'DON');
      final displayLetters = playerState.letters.split('').join('-');
      
      expect(displayLetters, 'D-O-N');
    });    test('should handle one dart mode correctly', () async {
      final oneController = DonkeyGameController(
        players: ['Alice', 'Bob'],
        variant: DonkeyVariant.oneDart,
        isTest: true,
      );
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(oneController.maxDartsPerTurn, 1);
      expect(oneController.currentPlayer, 0); // Alice starts
      
      // Alice scores - should advance immediately to Bob since it's one dart mode
      oneController.score(15);
      expect(oneController.currentPlayer, 1); // Should be Bob now
      expect(oneController.currentTarget, 15); // Alice set the target
      
      // Wait for turn change animation to complete
      await Future.delayed(const Duration(milliseconds: 500));
      expect(oneController.dartsThrown, 0); // New turn, reset darts
      expect(oneController.isTurnComplete, false); // New turn not complete yet
      
      oneController.dispose();
    });test('should handle three dart mode correctly', () async {
      final threeController = DonkeyGameController(
        players: ['Alice', 'Bob'],
        variant: DonkeyVariant.threeDart,
        isTest: true,
      );
      
      // Wait for async initialization
      await Future.delayed(const Duration(milliseconds: 100));      expect(threeController.maxDartsPerTurn, 3);
      
      threeController.score(5);
      expect(threeController.isTurnComplete, false);
      expect(threeController.dartsThrown, 1);
      
      threeController.score(10);
      expect(threeController.isTurnComplete, false);
      expect(threeController.dartsThrown, 2);
      expect(threeController.currentTurnScore, 15); // 5 + 10
      
      threeController.score(5);
      // Turn completes immediately since we've thrown 3 darts
      
      // Wait for turn change
      await Future.delayed(const Duration(milliseconds: 500));
      expect(threeController.dartsThrown, 0); // New turn should have started
      expect(threeController.currentPlayer, 1); // Should advance to next player
      expect(threeController.currentTarget, 20); // First player should have set target to 20
      
      threeController.dispose();
    });    test('should handle miss correctly', () async {
      final missController = DonkeyGameController(
        players: ['Alice', 'Bob'],
        variant: DonkeyVariant.oneDart,
        isTest: true,
      );
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // First set a target - Alice scores 20
      missController.score(20);
      await Future.delayed(const Duration(milliseconds: 500));
      
      expect(missController.currentTarget, 20);
      expect(missController.currentPlayer, 1); // Bob's turn
      
      // Now Bob misses
      missController.scoreMiss();
      
      // Wait for turn completion
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Bob should get a letter for missing when target was 20
      final bobState = missController.getPlayerState('Bob');
      expect(bobState.letters.length, 1);
      
      missController.dispose();
    });test('should handle undo correctly', () async {
      // Use a three-dart controller for undo testing  
      final threeController = DonkeyGameController(
        players: ['Alice', 'Bob'],
        variant: DonkeyVariant.threeDart,
        isTest: true,
      );
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      threeController.score(20);
      expect(threeController.currentTurnScore, 20);
      expect(threeController.dartsThrown, 1);
      
      threeController.undoLastThrow();
      expect(threeController.currentTurnScore, 0);
      expect(threeController.dartsThrown, 0);
      
      threeController.dispose();
    });test('should handle multipliers correctly in three dart mode', () async {
      final threeController = DonkeyGameController(
        players: ['Alice', 'Bob'],
        variant: DonkeyVariant.threeDart,
        isTest: true,
      );
      
      // Wait for async initialization
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Note: Multipliers are now handled by ScoringButtons widget
      threeController.score(40, 'D20'); // Double 20 = 40
      
      expect(threeController.currentTurnScore, 40);
      expect(threeController.currentTurnDartLabels.last, 'D20');
      
      threeController.dispose();
    });
  });
}
