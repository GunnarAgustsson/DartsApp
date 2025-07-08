import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/services/cricket_game_service.dart';
import 'package:dars_scoring_app/models/app_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Cricket Game Controller Overlay Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Cannot score during turn changes (button disable bug fix)', () async {
      // Create controller with 2 players
      final controller = CricketGameController(
        players: ['Player 1', 'Player 2'],
        variant: CricketVariant.standard,
      );

      // Initial state
      expect(controller.currentPlayer, equals(0)); // Player 1
      expect(controller.dartsThrown, equals(0));
      expect(controller.isTurnChanging, isFalse);
      expect(controller.showTurnChange, isFalse);

      // Score 2 darts normally
      await controller.score(20); // First dart
      expect(controller.dartsThrown, equals(1));
      expect(controller.isTurnChanging, isFalse);
      
      await controller.score(20); // Second dart  
      expect(controller.dartsThrown, equals(2));
      expect(controller.isTurnChanging, isFalse);
      
      // Third dart should trigger turn change and reset dartsThrown
      await controller.score(20); // Third dart - should trigger turn change
      expect(controller.dartsThrown, equals(0)); // Reset to 0 after turn change starts
      expect(controller.isTurnChanging, isTrue); // Turn change in progress
      expect(controller.showTurnChange, isTrue); // Overlay should be visible
      expect(controller.currentPlayer, equals(0)); // Still Player 1 until turn change completes

      // Try to score during turn change - should be blocked
      final throwCountBefore = controller.currentGame.throws.length;
      await controller.score(20); // This should be ignored
      final throwCountAfter = controller.currentGame.throws.length;
      
      // No new throw should be recorded because scoring was blocked
      expect(throwCountAfter, equals(throwCountBefore));
      expect(controller.dartsThrown, equals(0)); // Should still be 0
      expect(controller.currentPlayer, equals(0)); // Should still be Player 1

      print('✅ Cricket bug fix verified: Scoring blocked during turn change');
      print('Turn change in progress: ${controller.isTurnChanging}');
      print('Overlay visible: ${controller.showTurnChange}');

      controller.dispose();
    });

    test('dismissOverlays completes turn change immediately', () async {
      // Create controller with 2 players
      final controller = CricketGameController(
        players: ['Player 1', 'Player 2'],
        variant: CricketVariant.standard,
      );

      // Score 3 darts to trigger turn change
      await controller.score(20);
      await controller.score(20);
      await controller.score(20);
      
      // Verify turn change is in progress
      expect(controller.isTurnChanging, isTrue);
      expect(controller.showTurnChange, isTrue);
      expect(controller.currentPlayer, equals(0)); // Still Player 1

      // Dismiss overlays (simulating tap to close)
      controller.dismissOverlays();
      
      // Turn change should complete immediately
      expect(controller.isTurnChanging, isFalse);
      expect(controller.showTurnChange, isFalse);
      expect(controller.currentPlayer, equals(1)); // Now Player 2
      expect(controller.dartsThrown, equals(0)); // Reset to 0

      // Should now be able to score normally
      await controller.score(20);
      expect(controller.dartsThrown, equals(1));
      expect(controller.currentPlayer, equals(1)); // Still Player 2

      print('✅ dismissOverlays working correctly');
      print('Turn changed from Player 1 to Player 2 immediately');

      controller.dispose();
    });

    test('Normal scoring works when not in turn change', () async {
      // Create controller with 2 players
      final controller = CricketGameController(
        players: ['Player 1', 'Player 2'],
        variant: CricketVariant.standard,
      );

      // Score normally (should work)
      await controller.score(20);
      expect(controller.dartsThrown, equals(1));
      expect(controller.isTurnChanging, isFalse);
      expect(controller.showTurnChange, isFalse);

      print('✅ Normal Cricket scoring works correctly');

      controller.dispose();
    });
  });
}
