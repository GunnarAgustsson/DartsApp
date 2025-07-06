import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:dars_scoring_app/theme/app_colors.dart';

class SpiderWebPainter extends CustomPainter {
  
  SpiderWebPainter(Map<int, int> hitMap, this.maxHits, this.brightness) : 
    originalHitMap = Map.from(hitMap), // Store a copy of the original map
    _processedHitMap = {
      // Initialize all dartboard numbers and bullseye numbers
      for (final number in const [
        20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5, // Standard numbers
        25, 50 // Bullseye numbers
      ])
        number: hitMap[number] ?? 0, // If number not in hitMap, default to 0
    };
  final Map<int, int> originalHitMap; // To store the original hitMap for comparison
  final Map<int, int> _processedHitMap; // Internal map with all numbers initialized
  final int maxHits;
  final Brightness brightness;
  
  // Standard dartboard arrangement (clockwise from top)
  final List<int> dartboardNumbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    
  final Paint webPaint = Paint()
      ..color = brightness == Brightness.dark ? Colors.white30 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
        final Paint hitPaint = Paint()
      ..color = brightness == Brightness.dark 
          ? AppColors.primaryGreen.shade600.withOpacity(0.7) 
          : AppColors.primaryGreen.withOpacity(0.6)
      ..style = PaintingStyle.fill;
      
    final Paint numberCirclePaint = Paint()
      ..color = brightness == Brightness.dark 
          ? AppColors.darkCardBackground.withOpacity(0.5) 
          : AppColors.lightCardBackground.withOpacity(0.7)
      ..style = PaintingStyle.fill;
      
  final TextStyle numberStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    );
    
    // Draw concentric circles
    const int rings = 5;
    for (int i = 1; i <= rings; i++) {
      final double ringRadius = radius * i / rings;
      canvas.drawCircle(center, ringRadius, webPaint);
    }
    
    // Draw radial lines for each dartboard number position
    for (int i = 0; i < dartboardNumbers.length; i++) {
      final double angle = 2 * math.pi * i / dartboardNumbers.length - math.pi / 2;
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), webPaint);
    }
    
    // Draw hit polygon
    final Path hitPath = Path();
    bool firstPoint = true;
      for (int i = 0; i < dartboardNumbers.length; i++) {
      final int number = dartboardNumbers[i];
      final int hitCount = _processedHitMap[number]!; // Use processed map
        // Calculate the percentage of max hits with a minimum radius for zero hits
      final double percentage = maxHits > 0 ? hitCount / maxHits : 0;
      final double angle = 2 * math.pi * i / dartboardNumbers.length - math.pi / 2;
      
      // Set minimum radius for zero hits to show a more visible circle (about 15% of the radius)
      final double minRadius = radius * 0.15;
      final double hitRadius = hitCount == 0 ? minRadius : math.max(minRadius, radius * percentage);
      
      final double x = center.dx + hitRadius * math.cos(angle);
      final double y = center.dy + hitRadius * math.sin(angle);
      
      if (firstPoint) {
        hitPath.moveTo(x, y);
        firstPoint = false;
      } else {
        hitPath.lineTo(x, y);
      }
    }
    
    hitPath.close();
    // Fill with the existing blue color
    canvas.drawPath(hitPath, hitPaint);
      // Add this code: Draw a more visible outline around the shape
    final Paint outlinePaint = Paint()
      ..color = brightness == Brightness.dark 
          ? Colors.white.withOpacity(0.6)
          : Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
  
    canvas.drawPath(hitPath, outlinePaint);
    
    // Draw dart numbers in a circle
    for (int i = 0; i < dartboardNumbers.length; i++) {
      final int number = dartboardNumbers[i];
      final double angle = 2 * math.pi * i / dartboardNumbers.length - math.pi / 2;
      
      // Number circle position (slightly outside the web)
      final double numberRadius = radius + 15;
      final double x = center.dx + numberRadius * math.cos(angle);
      final double y = center.dy + numberRadius * math.sin(angle);
      
      // Draw circle background for number
      canvas.drawCircle(Offset(x, y), 10, numberCirclePaint);
      
      // Draw number text
      final hitCount = _processedHitMap[number]!; // Use processed map
      final TextSpan span = TextSpan(
        text: number.toString(),
        style: numberStyle.copyWith(          color: hitCount > 0 ? 
            Color.lerp(AppColors.primaryGreen, AppColors.secondaryRed, hitCount / (maxHits > 0 ? maxHits : 1)) : 
            numberStyle.color,
          fontWeight: hitCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      );
      
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
    
    // Draw bullseye (25/50) if exists in data
    final int bullCount = (_processedHitMap[25]! + _processedHitMap[50]!); // Use processed map
    // Only draw bullseye indicator if it has hits.
    if (bullCount > 0 && maxHits > 0) {
      final double bullPercentage = bullCount / maxHits; // Ensure maxHits is not zero
      canvas.drawCircle(
        center, 
        10, // Keep a fixed size for the bullseye indicator for now
        Paint()
          ..color = Color.lerp(AppColors.primaryGreen, AppColors.secondaryRed, bullPercentage) ?? AppColors.primaryGreen
          ..style = PaintingStyle.fill
      );
      
      final TextSpan bullSpan = TextSpan(
        text: 'B',
        style: numberStyle.copyWith(
          color: Colors.white,
          fontSize: 10,
        ),
      );
      
      final TextPainter bullPainter = TextPainter(
        text: bullSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      bullPainter.layout();
      bullPainter.paint(
        canvas, 
        Offset(center.dx - bullPainter.width / 2, center.dy - bullPainter.height / 2)
      );
    }
    
    // Draw legend
    _drawLegend(canvas, size, rings);
  }
    void _drawLegend(Canvas canvas, Size size, int rings) {
    final TextStyle legendStyle = TextStyle(
      fontSize: 10,
      color: brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
    );
    
    // Draw numerical indicators based on maxHits
    if (rings > 0) {
      for (int i = 1; i <= rings; i++) {
        // Calculate the hit value for this ring
        // The outermost ring (i == rings) should represent maxHits
        final double valueForRing = (maxHits.toDouble() * i) / rings;
        final String label = valueForRing.round().toString();
        
        final TextSpan span = TextSpan(text: label, style: legendStyle);
        final TextPainter tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        );
        
        tp.layout();
        tp.paint(canvas, Offset(size.width / 2 + 5, size.height / 2 - (size.height / 2 - 20) * i / rings - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(SpiderWebPainter oldDelegate) {
    return oldDelegate.originalHitMap != originalHitMap || // Compare with the original map
           oldDelegate.maxHits != maxHits ||
           oldDelegate.brightness != brightness;
  }
}