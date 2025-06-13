import 'package:flutter_test/flutter_test.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';

void main() {
  // Test common checkout paths for DoubleOut
  group('Common DoubleOut paths', () {
    test('checkout for 170 - max possible checkout', () {
      final result = bestCheckouts(170, 3, CheckoutRule.doubleOut);
      print('170 checkout: ${result.first.join(' ')}');
    });
  
    test('checkout for 121', () {
      final result = bestCheckouts(121, 3, CheckoutRule.doubleOut);
      print('121 checkout: ${result.first.join(' ')}');
    });
  
    test('checkout for 67', () {
      final result = bestCheckouts(67, 3, CheckoutRule.doubleOut);
      print('67 checkout: ${result.first.join(' ')}');
    });
    
    test('checkout for 40', () {
      final result = bestCheckouts(40, 3, CheckoutRule.doubleOut);
      print('40 checkout: ${result.first.join(' ')}');
    });
    
    test('checkout for 32', () {
      final result = bestCheckouts(32, 3, CheckoutRule.doubleOut);
      print('32 checkout: ${result.first.join(' ')}');
    });
  });
  
  // Test all rules for some key values
  group('Different rule tests', () {
    test('checkout for 121 with all rules', () {
      print('121 checkout with DoubleOut: ${bestCheckouts(121, 3, CheckoutRule.doubleOut).first.join(' ')}');
      print('121 checkout with ExtendedOut: ${bestCheckouts(121, 3, CheckoutRule.extendedOut).first.join(' ')}');
      print('121 checkout with ExactOut: ${bestCheckouts(121, 3, CheckoutRule.exactOut).first.join(' ')}');
      print('121 checkout with OpenFinish: ${bestCheckouts(121, 3, CheckoutRule.openFinish).first.join(' ')}');
    });
    
    test('checkout for 67 with all rules', () {
      print('67 checkout with DoubleOut: ${bestCheckouts(67, 3, CheckoutRule.doubleOut).first.join(' ')}');
      print('67 checkout with ExtendedOut: ${bestCheckouts(67, 3, CheckoutRule.extendedOut).first.join(' ')}');
      print('67 checkout with ExactOut: ${bestCheckouts(67, 3, CheckoutRule.exactOut).first.join(' ')}');
      print('67 checkout with OpenFinish: ${bestCheckouts(67, 3, CheckoutRule.openFinish).first.join(' ')}');
    });
    
    test('checkout for 32 with all rules', () {
      print('32 checkout with DoubleOut: ${bestCheckouts(32, 3, CheckoutRule.doubleOut).first.join(' ')}');
      print('32 checkout with ExtendedOut: ${bestCheckouts(32, 3, CheckoutRule.extendedOut).first.join(' ')}');
      print('32 checkout with ExactOut: ${bestCheckouts(32, 3, CheckoutRule.exactOut).first.join(' ')}');
      print('32 checkout with OpenFinish: ${bestCheckouts(32, 3, CheckoutRule.openFinish).first.join(' ')}');
    });
  });
}
