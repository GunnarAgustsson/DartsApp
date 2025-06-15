import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:dars_scoring_app/theme/app_colors.dart';

class SpiderWebPainter extends CustomPainter {
  final Map<int, int> hitMap;
  final int maxHits;
  final Brightness brightness;
  
  // Standard dartboard arrangement (clockwise from top)
  final List<int> dartboardNumbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
  
  SpiderWebPainter(this.hitMap, this.maxHits, this.brightness);

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
          ? AppColors.primaryGreen.shade700.withOpacity(0.5) 
          : AppColors.primaryGreen.withOpacity(0.5)
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
      final int hitCount = hitMap[number] ?? 0;
      
      // Calculate the percentage of max hits
      final double percentage = maxHits > 0 ? hitCount / maxHits : 0;
      final double angle = 2 * math.pi * i / dartboardNumbers.length - math.pi / 2;
      final double hitRadius = radius * percentage;
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
    
    // Add this code: Draw a 1px black outline around the shape
    final Paint outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
  
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
      final hitCount = hitMap[number] ?? 0;
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
    final int bullCount = (hitMap[25] ?? 0) + (hitMap[50] ?? 0);
    if (bullCount > 0) {
      final double bullPercentage = maxHits > 0 ? bullCount / maxHits : 0;
      canvas.drawCircle(
        center,        10, 
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
    
    // Draw percentage indicators
    for (int i = 1; i <= rings; i++) {
      final double percentage = i / rings * 100;
      final String label = '${percentage.toInt()}%';
      
      final TextSpan span = TextSpan(text: label, style: legendStyle);
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      
      tp.layout();
      tp.paint(canvas, Offset(size.width / 2 + 5, size.height / 2 - (size.height / 2 - 20) * i / rings - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(SpiderWebPainter oldDelegate) {
    return oldDelegate.hitMap != hitMap || 
           oldDelegate.maxHits != maxHits ||
           oldDelegate.brightness != brightness;
  }
}