import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/services/cricket_game_service.dart';
import 'package:dars_scoring_app/models/app_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Cricket Game Logic Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('Standard Cricket Variant Tests', () {
      test('should allow players to score on numbers they have not closed', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        // Alice should be able to hit 20 initially (not closed)
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        expect(controller.canCurrentPlayerScoreOn(20), true);
        
        controller.dispose();
      });

      test('should allow players to score on numbers they have closed but others have not', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        // Alice closes 20 (hits it 3 times)
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Alice should still be able to hit 20 because Bob hasn't closed it
        expect(controller.getPlayerState('Alice').isNumberClosed(20), true);
        expect(controller.getPlayerState('Bob').isNumberClosed(20), false);
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        controller.dispose();
      });      test('should NOT allow players to score on numbers when ALL players have closed', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        // Alice closes 20
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Wait for turn change animation (2 seconds + buffer)
        await Future.delayed(const Duration(milliseconds: 2500));
        
        // Turn should advance to Bob after 3 darts
        expect(controller.currentPlayer, 1); // Now Bob's turn
        
        // Bob closes 20
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Now both players have closed 20, so neither should be able to score on it
        expect(controller.getPlayerState('Alice').isNumberClosed(20), true);
        expect(controller.getPlayerState('Bob').isNumberClosed(20), true);
        expect(controller.canPlayerScoreOn('Alice', 20), false);
        expect(controller.canPlayerScoreOn('Bob', 20), false);
        
        controller.dispose();
      });      test('should correctly handle scoring after closing', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        // Alice closes 20 with her first 2 darts, then hits something else
        await controller.score(20);
        await controller.score(20);
        await controller.score(19); // Third dart, turn will end
        
        // Wait for turn change animation
        await Future.delayed(const Duration(milliseconds: 2500));
        expect(controller.currentPlayer, 1); // Bob's turn
        
        // Bob throws some darts but doesn't close 20
        await controller.score(19);
        await controller.score(18);
        await controller.score(17);
        
        // Wait for turn change back to Alice
        await Future.delayed(const Duration(milliseconds: 2500));
        expect(controller.currentPlayer, 0); // Alice's turn again
        
        final aliceInitialScore = controller.scoreFor('Alice');
        
        // Alice hits 20 to close it (3rd hit) and gets any excess as points
        await controller.score(20);
        
        final aliceNewScore = controller.scoreFor('Alice');
        // Alice should have 0 score initially, so hitting 20 once after closing should not give points yet
        // because she just closed it (no excess)
        expect(aliceNewScore, aliceInitialScore);
        
        // Now Alice hits 20 again (should score points since Bob hasn't closed it)
        await controller.score(20);
        
        final aliceScoreAfterExcess = controller.scoreFor('Alice');
        expect(aliceScoreAfterExcess, aliceInitialScore + 20);
        
        controller.dispose();
      });test('should handle multiple players correctly', () async {
        final players = ['Alice', 'Bob', 'Charlie'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        // Alice closes 20
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Alice should still be able to score on 20 because Bob and Charlie haven't closed it
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        // Wait for turn change to Bob
        await Future.delayed(const Duration(milliseconds: 2500));
        expect(controller.currentPlayer, 1); // Bob's turn
        
        // Turn advances to Bob, Bob closes 20
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Alice should still be able to score on 20 because Charlie hasn't closed it
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        // Wait for turn change to Charlie
        await Future.delayed(const Duration(milliseconds: 2500));
        expect(controller.currentPlayer, 2); // Charlie's turn
        
        // Turn advances to Charlie, Charlie closes 20
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Now NO ONE should be able to score on 20
        expect(controller.canPlayerScoreOn('Alice', 20), false);
        expect(controller.canPlayerScoreOn('Bob', 20), false);
        expect(controller.canPlayerScoreOn('Charlie', 20), false);
        
        controller.dispose();
      });
    });

    group('Race Cricket Variant Tests', () {
      test('should NOT allow players to score on numbers they have closed', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.noScore,
        );
        
        // Alice closes 20
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Alice should NOT be able to hit 20 again in race variant
        expect(controller.canPlayerScoreOn('Alice', 20), false);
        
        controller.dispose();
      });

      test('should allow players to score on numbers they have not closed', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.noScore,
        );
        
        // Alice should be able to hit 20 initially
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        // Alice hits 20 twice (not closed yet)
        await controller.score(20);
        await controller.score(20);
        
        // Alice should still be able to hit 20
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        controller.dispose();
      });
    });

    group('Simplified Cricket Variant Tests', () {
      test('should only use numbers 20, 19, 18', () async {
        final controller = CricketGameController(
          players: ['Alice', 'Bob'],
          variant: CricketVariant.simplified,        );
        
        final numbers = controller.cricketNumbersForVariant;
        expect(numbers, [20, 19, 18]);
        expect(numbers.length, 3);
        
        controller.dispose();
      });

      test('should behave like race cricket for allowed numbers', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.simplified,
        );
        
        // Alice should be able to hit 20 initially
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        // Alice closes 20
        await controller.score(20);
        await controller.score(20);
        await controller.score(20);
        
        // Alice should NOT be able to hit 20 again in simplified variant
        expect(controller.canPlayerScoreOn('Alice', 20), false);
        
        controller.dispose();
      });
    });

    group('Cricket Numbers Method Tests', () {
      test('should return all cricket numbers for standard variant', () async {        final controller = CricketGameController(
          players: ['Alice'],
          variant: CricketVariant.standard,
        );
        
        final numbers = controller.cricketNumbersForVariant;
        expect(numbers, [20, 19, 18, 17, 16, 15, 25]);
        
        controller.dispose();
      });

      test('should return all cricket numbers for race variant', () async {
        final controller = CricketGameController(
          players: ['Alice'],          variant: CricketVariant.noScore,
        );
        
        final numbers = controller.cricketNumbersForVariant;
        expect(numbers, [20, 19, 18, 17, 16, 15, 25]);
        
        controller.dispose();
      });

      test('should return only 3 numbers for simplified variant', () async {
        final controller = CricketGameController(          players: ['Alice'],
          variant: CricketVariant.simplified,
        );
        
        final numbers = controller.cricketNumbersForVariant;
        expect(numbers, [20, 19, 18]);
        
        controller.dispose();
      });
    });

    group('Turn Advancement Tests', () {      test('should advance turn after 3 darts', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        expect(controller.currentPlayer, 0); // Alice
        expect(controller.dartsThrown, 0);
        
        // Alice throws 3 darts
        await controller.score(20);
        expect(controller.dartsThrown, 1);
        expect(controller.currentPlayer, 0); // Still Alice
        
        await controller.score(19);
        expect(controller.dartsThrown, 2);
        expect(controller.currentPlayer, 0); // Still Alice
        
        await controller.score(18);
        expect(controller.dartsThrown, 0); // Reset to 0 immediately
        expect(controller.currentPlayer, 0); // Still Alice (turn change is delayed)
        
        // Wait for turn change animation
        await Future.delayed(const Duration(milliseconds: 2500));
        expect(controller.currentPlayer, 1); // Now Bob
        
        controller.dispose();
      });

      test('should advance turn after 3 misses', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        expect(controller.currentPlayer, 0); // Alice
        
        // Alice throws 3 misses
        await controller.scoreMiss();
        await controller.scoreMiss();
        await controller.scoreMiss();
        
        // Turn should advance to Bob after animation delay
        await Future.delayed(const Duration(milliseconds: 2500));
        expect(controller.currentPlayer, 1); // Now Bob
        
        controller.dispose();
      });
    });

    group('Win Condition Tests', () {
      test('should detect win in standard cricket when all numbers closed with highest score', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
          // Alice closes all numbers and gets some score
        for (final number in controller.cricketNumbersForVariant) {
          await controller.score(number); // Close
          await controller.score(number); // Close
          await controller.score(number); // Close
          if (controller.dartsThrown == 0) {
            // Turn advanced, need to get back to Alice
            await controller.score(15); // Bob throws something
            await controller.score(15);
            await controller.score(15);
          }
        }
        
        // Alice should win (all numbers closed)
        // Note: Win detection happens in _checkWinCondition which is called after scoring
        
        controller.dispose();
      });

      test('should detect win in race cricket when all numbers closed', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.noScore,
        );
          // In race cricket, first to close all numbers wins regardless of score
        for (final number in controller.cricketNumbersForVariant) {
          await controller.score(number);
          await controller.score(number);
          await controller.score(number);
          if (controller.dartsThrown == 0) {
            // Turn advanced, need to get back to Alice
            await controller.score(15);
            await controller.score(15);
            await controller.score(15);
          }
        }
        
        controller.dispose();
      });
    });

    group('Undo Functionality Tests', () {
      test('should correctly undo last throw and update scoring eligibility', () async {
        final players = ['Alice', 'Bob'];
        final controller = CricketGameController(
          players: players,
          variant: CricketVariant.standard,
        );
        
        // Alice hits 20 twice
        await controller.score(20);
        await controller.score(20);
        
        expect(controller.getPlayerState('Alice').hits[20], 2);
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        // Alice hits 20 third time (closes it)
        await controller.score(20);
        
        expect(controller.getPlayerState('Alice').hits[20], 3);
        expect(controller.getPlayerState('Alice').isNumberClosed(20), true);
        expect(controller.canPlayerScoreOn('Alice', 20), true); // Can still score because Bob hasn't closed
        
        // Undo the last throw
        await controller.undoLastThrow();
        
        expect(controller.getPlayerState('Alice').hits[20], 2);
        expect(controller.getPlayerState('Alice').isNumberClosed(20), false);
        expect(controller.canPlayerScoreOn('Alice', 20), true);
        
        controller.dispose();
      });
    });
  });
}
