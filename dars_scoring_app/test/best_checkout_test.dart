import 'package:flutter_test/flutter_test.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';

void main() {
  group('bestCheckouts (doubleOut)', () {
    test('no doubleOut finish possible for 1', () {
      final result = bestCheckouts(1, 3, CheckoutRule.doubleOut);
      expect(result, isEmpty);
    });

    test('single‐dart DB finish under doubleOut for 50', () {
      final result = bestCheckouts(50, 3, CheckoutRule.doubleOut);
      expect(result, equals([['DB']]));
    });

    test('single‐dart D3 finish under doubleOut for 6', () {
      final result = bestCheckouts(6, 3, CheckoutRule.doubleOut);
      expect(result, equals([['D3']]));
    });

    test('single‐dart D20 finish under doubleOut for 40 with 1 dart left', () {
      final result = bestCheckouts(40, 1, CheckoutRule.doubleOut);
      expect(result, equals([['D20']]));
    });

    test('single‐dart D20 finish under doubleOut for 40 with 2 darts left', () {
      final result = bestCheckouts(40, 2, CheckoutRule.doubleOut);
      expect(result, equals([['D20']]));
    });

    test('two‐dart T20,D20 finish under doubleOut for 100', () {
      final result = bestCheckouts(100, 3, CheckoutRule.doubleOut);
      expect(result.first, equals(['T20', 'D20']));
    });

    test('two‐dart D16 finish under doubleOut for 32 with 2 darts', () {
      final result = bestCheckouts(32, 2, CheckoutRule.doubleOut);
      expect(result.first, equals(['D16']));
    });

    test('two‐dart D16 finish under doubleOut for 32 with 3 darts', () {
      final result = bestCheckouts(32, 3, CheckoutRule.doubleOut);
      expect(result.first, equals(['D16']));
    });

    test('single‐dart D7 finish under doubleOut for 14', () {
      final result = bestCheckouts(14, 3, CheckoutRule.doubleOut);
      expect(result, equals([['D7']]));
    });

    test('two‐dart D20,D20 finish under doubleOut for 80', () {
      final result = bestCheckouts(80, 2, CheckoutRule.doubleOut);
      expect(result.first, equals(['D20', 'D20']));
    });

    test('three‐dart T20,T20,DB finish under doubleOut for 170', () {
      final result = bestCheckouts(170, 3, CheckoutRule.doubleOut);
      expect(result.first, equals(['T20', 'T20', 'DB']));
    });

    test('three‐dart T20,T20 finish under doubleOut for 120', () {
      final result = bestCheckouts(120, 3, CheckoutRule.doubleOut);
      expect(result.first, equals(['T18', 'D13', 'D20']));
    });

    test('limit=2 returns top 2 combos for 100 under doubleOut', () {
      final result = bestCheckouts(100, 3, CheckoutRule.doubleOut, limit: 2);
      expect(result, equals([['T20', 'D20'], ['DB', 'DB']]));
    });
  });

  group('bestCheckouts (exactOut)', () {
    test('single‐dart 25 finish under exactOut', () {
      final result = bestCheckouts(25, 1, CheckoutRule.exactOut);
      expect(result, equals([['25']]));
    });

    test('single‐dart S3 finish under exactOut', () {
      final result = bestCheckouts(3, 2, CheckoutRule.exactOut);
      expect(result.first, equals(['S3']));
    });

    test('single‐dart D13 finish under exactOut for 26', () {
      final result = bestCheckouts(26, 2, CheckoutRule.exactOut);
      expect(result, equals([['D13']]));
    });

    test('single‐dart S5 finish under exactOut for 5', () {
      final result = bestCheckouts(5, 3, CheckoutRule.exactOut);
      expect(result.first, equals(['S5']));
    });

    test('single‐dart DB finish under exactOut for 50', () {
      final result = bestCheckouts(50, 2, CheckoutRule.exactOut);
      expect(result.first, equals(['DB']));
    });

    test('two‐dart D20,S12 finish under exactOut for 52', () {
      final result = bestCheckouts(52, 2, CheckoutRule.exactOut);
      expect(result.first, equals(['D20', 'S12']));
    });

    test('single‐dart S1 finish under exactOut for 1', () {
      final result = bestCheckouts(1, 3, CheckoutRule.exactOut);
      expect(result.first, equals(['S1']));
    });
  });
  group('bestCheckouts (extendedOut)', () {
    test('single‐dart T20 finish under extendedOut for 60', () {
      final result = bestCheckouts(60, 1, CheckoutRule.extendedOut);
      expect(result.first, equals(['T20']));
    });

    test('single‐dart T18 finish under extendedOut for 54', () {
      final result = bestCheckouts(54, 2, CheckoutRule.extendedOut);
      expect(result.first, equals(['T18']));
    });

    test('two‐dart S13, D20 finish under extendedOut for 53', () {
      final result = bestCheckouts(53, 2, CheckoutRule.extendedOut);
      expect(result.first, equals(['S13', 'D20']));
    });

    test('single‐dart T10 finish under extendedOut for 30', () {
      final result = bestCheckouts(30, 1, CheckoutRule.extendedOut);
      expect(result.first, equals(['D15']));
    });

    test('single‐dart D14 finish under extendedOut for 28', () {
      final result = bestCheckouts(28, 1, CheckoutRule.extendedOut);
      expect(result.first, equals(['D14']));
    });

    test('two‐dart S1,D14 finish under extendedOut for 29', () {
      final result = bestCheckouts(29, 2, CheckoutRule.extendedOut);
      expect(result.first, equals(['S1', 'D14']));
    });

    test('one‐dart D15 finish under extendedOut for 30', () {
      final result = bestCheckouts(30, 3, CheckoutRule.extendedOut);
      expect(result.first, equals(['D15']));
    });

    test('no extendedOut finish possible for 1', () {
      final result = bestCheckouts(1, 3, CheckoutRule.extendedOut);
      expect(result, isEmpty);
    });

    test('single‐dart D16 finish under extendedOut for 32', () {
      final result = bestCheckouts(32, 1, CheckoutRule.extendedOut);
      expect(result.first, equals(['D16']));
    });

    test('single‐dart T17 finish under extendedOut for 51', () {
      final result = bestCheckouts(51, 2, CheckoutRule.extendedOut);
      expect(result.first, equals(['T17']));
    });
  });
}