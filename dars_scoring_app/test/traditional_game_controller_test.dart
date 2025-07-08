import 'package:flutter_test/flutter_test.dart';
import 'package:dars_scoring_app/services/traditional_game_service.dart';

void main() {
  group('Traditional Game Controller Scoring Tests', () {
    test('Cannot score during turn changes (bug fix verification)', () async {
      // Create controller with 2 players
      final controller = TraditionalGameController(
        startingScore: 501,
        players: ['Player 1', 'Player 2'],
      );

      // Initial state
      expect(controller.currentPlayer, equals(0)); // Player 1
      expect(controller.dartsThrown, equals(0));
      expect(controller.isTurnChanging, isFalse);
      expect(controller.scoreFor('Player 1'), equals(501));

      // Score 3 darts to trigger turn change
      await controller.score(20, '20'); // First dart
      expect(controller.dartsThrown, equals(1));
      expect(controller.isTurnChanging, isFalse);
      
      await controller.score(20, '20'); // Second dart  
      expect(controller.dartsThrown, equals(2));
      expect(controller.isTurnChanging, isFalse);
      
      await controller.score(20, '20'); // Third dart - should trigger turn change
      expect(controller.dartsThrown, equals(3));
      expect(controller.isTurnChanging, isTrue); // Turn change in progress
      expect(controller.currentPlayer, equals(0)); // Still Player 1 until turn change completes

      // Try to score during turn change - should be blocked
      final scoreBefore = controller.scoreFor('Player 1');
      await controller.score(20, '20'); // This should be ignored
      final scoreAfter = controller.scoreFor('Player 1');
      
      // Score should not have changed because scoring was blocked
      expect(scoreAfter, equals(scoreBefore));
      expect(controller.dartsThrown, equals(3)); // Should still be 3
      expect(controller.currentPlayer, equals(0)); // Should still be Player 1

      print('✅ Bug fix verified: Scoring blocked during turn change');
      print('Player 1 score remained at $scoreBefore when trying to score during turn change');

      controller.dispose();
    });

    test('Normal scoring works when not in turn change', () async {
      // Create controller with 2 players
      final controller = TraditionalGameController(
        startingScore: 501,
        players: ['Player 1', 'Player 2'],
      );

      // Score normally (should work)
      expect(controller.scoreFor('Player 1'), equals(501));
      await controller.score(20, '20');
      expect(controller.scoreFor('Player 1'), equals(481));
      expect(controller.dartsThrown, equals(1));
      expect(controller.isTurnChanging, isFalse);

      print('✅ Normal scoring works correctly');

      controller.dispose();
    });
  });
}
