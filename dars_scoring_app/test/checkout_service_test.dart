import 'package:flutter_test/flutter_test.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';
import 'package:dars_scoring_app/services/checkout_service.dart';

void main() {
  group('CheckoutService', () {
    test('returns standardized paths for common checkouts', () {
      // Tests for scores with well-known checkout paths
      expect(CheckoutService.getBestCheckout(170, 3, CheckoutRule.doubleOut), 
          equals(['T20', 'T20', 'DB']));
          
      expect(CheckoutService.getBestCheckout(121, 3, CheckoutRule.doubleOut), 
          equals(['T20', 'S11', 'DB']));
          
      expect(CheckoutService.getBestCheckout(67, 3, CheckoutRule.doubleOut), 
          equals(['T17', 'D8']));
          
      expect(CheckoutService.getBestCheckout(50, 1, CheckoutRule.doubleOut), 
          equals(['DB']));
          
      expect(CheckoutService.getBestCheckout(32, 1, CheckoutRule.doubleOut), 
          equals(['D16']));
    });
      test('handles different checkout rules', () {
      // Test standard checkouts for ExtendedOut
      final extendedOut121 = CheckoutService.getBestCheckout(121, 3, CheckoutRule.extendedOut);
      expect(extendedOut121, equals(['T20', 'S11', 'DB']), reason: 'ExtendedOut should use standard checkout for 121');
      
      final extendedOut67 = CheckoutService.getBestCheckout(67, 3, CheckoutRule.extendedOut);
      expect(extendedOut67, equals(['T17', 'D8']), reason: 'ExtendedOut should use standard checkout for 67');
      
      // Test standard checkouts for ExactOut
      final exactOut121 = CheckoutService.getBestCheckout(121, 3, CheckoutRule.exactOut);
      expect(exactOut121, equals(['T20', 'T20', 'S1']), reason: 'ExactOut should use standard checkout for 121');
      
      final exactOut67 = CheckoutService.getBestCheckout(67, 3, CheckoutRule.exactOut);
      expect(exactOut67, equals(['T19', 'S10']), reason: 'ExactOut should use standard checkout for 67');
      
      // Test standard checkouts for OpenFinish
      final openFinish121 = CheckoutService.getBestCheckout(121, 3, CheckoutRule.openFinish);
      expect(openFinish121, equals(['T20', 'T20', 'S1']), reason: 'OpenFinish should use standard checkout for 121');
      
      final openFinish67 = CheckoutService.getBestCheckout(67, 3, CheckoutRule.openFinish);
      expect(openFinish67, equals(['T20', 'S7']), reason: 'OpenFinish should use standard checkout for 67');
    });
    
    test('handles impossible checkouts', () {
      // Tests for impossible checkouts (1 in doubleOut)
      expect(CheckoutService.getBestCheckout(1, 3, CheckoutRule.doubleOut), 
          equals([]));
    });
    
    test('generates comparable checkout paths when no standard exists', () {
      // For a non-standard checkout, should still provide a reasonable path
      final nonStandardPath = CheckoutService.getBestCheckout(159, 3, CheckoutRule.doubleOut);
      expect(nonStandardPath.isNotEmpty, isTrue);
    });
  });
}
