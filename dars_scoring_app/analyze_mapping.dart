import 'dart:math' as math;

void main() {
  const numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
  
  print('=== Where each number is drawn (after -90° rotation) ===');
  for (int i = 0; i < 20; i++) {
    final number = numbers[i];
    final angle = (i * 18 - 90) * math.pi / 180; // Drawing angle
    final x = math.cos(angle);
    final y = math.sin(angle);
    
    String position = '';
    if (y < -0.7) position = 'TOP';
    else if (y > 0.7) position = 'BOTTOM';
    else if (x > 0.7) position = 'RIGHT';
    else if (x < -0.7) position = 'LEFT';
    else if (x < 0 && y < 0) position = 'top-left';
    else if (x > 0 && y < 0) position = 'top-right';
    else if (x < 0 && y > 0) position = 'bottom-left';
    else if (x > 0 && y > 0) position = 'bottom-right';
    
    print('Number $number: segment $i, angle ${i * 18 - 90}°, pos (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}) -> $position');
  }
  
  print('\n=== What should the hit detection return for top-left hover? ===');
  // User is hovering over number 14 in top-left
  // Let's find where number 14 is drawn
  for (int i = 0; i < 20; i++) {
    if (numbers[i] == 14) {
      final drawAngle = i * 18 - 90;
      print('Number 14 is at segment $i, drawn at angle $drawAngle°');
      
      // So if user hovers at top-left (-0.7, -0.7), hit detection should return segment $i
      final dx = -0.7;
      final dy = -0.7;
      
      // Current hit detection
      double hitAngle = math.atan2(dx, -dy) * 180 / math.pi;
      if (hitAngle < 0) hitAngle += 360;
      
      print('Hit detection gives angle: ${hitAngle.toStringAsFixed(1)}°');
      print('We need this to map to segment $i, which spans ${i * 18 - 9}° to ${i * 18 + 9}°');
      
      // So we need: hitAngle = drawAngle (approximately)
      final adjustment = drawAngle - hitAngle;
      print('Adjustment needed: $adjustment° (drawAngle - hitAngle)');
      break;
    }
  }
}
