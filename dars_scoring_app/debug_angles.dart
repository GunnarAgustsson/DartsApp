import 'dart:math' as math;

void main() {
  const numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
  
  print('Segment drawing angles:');
  for (int i = 0; i < 20; i++) {
    final number = numbers[i];
    final startAngle = (i * 18 - 9);
    final endAngle = (i * 18 + 9);
    final centerAngle = i * 18;
    print('Segment $i (Number $number): ${startAngle}° to ${endAngle}°, center: ${centerAngle}°');
  }
  
  print('\nTesting hit detection for key positions:');
  final testPositions = [
    {'angle': 0, 'expected': 20, 'description': 'Top'},
    {'angle': 18, 'expected': 1, 'description': '18° clockwise'},
    {'angle': 90, 'expected': 6, 'description': 'Right'},
    {'angle': 180, 'expected': 3, 'description': 'Bottom'},
    {'angle': 270, 'expected': 11, 'description': 'Left'},
    {'angle': 350, 'expected': 20, 'description': 'Near top (-10°)'},
    {'angle': 10, 'expected': 20, 'description': 'Near top (+10°)'},
  ];
  
  for (final test in testPositions) {
    final angle = test['angle'] as int;
    final expected = test['expected'] as int;
    final description = test['description'] as String;
    
    // Hit detection calculation (corrected boundary logic)
    int segmentIndex;
    if (angle > 351 || angle <= 9) {
      segmentIndex = 0; // Number 20
    } else {
      // For other segments, shift by 9° and divide by 18°
      segmentIndex = ((angle - 9) / 18).floor() + 1;
    }
    
    int actual = numbers[segmentIndex];
    
    final match = actual == expected ? '✓' : '✗';
    print('$description ($angle°): expected $expected, got $actual $match (segment: $segmentIndex)');
  }
}
