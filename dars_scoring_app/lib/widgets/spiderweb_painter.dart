import 'dart:math';
import 'package:flutter/material.dart';

class SpiderWebPainter extends CustomPainter {
  final Map<int, int> hitHeatmap;
  final int maxHits;
  final Brightness brightness;

  SpiderWebPainter(this.hitHeatmap, this.maxHits, this.brightness);

  static const List<int> dartboardNumbers = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
    3, 19, 7, 16, 8, 11, 14, 9, 12, 5
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;

    // Draw adaptive background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: brightness == Brightness.dark
            ? [Colors.grey[900]!, Colors.black]
            : [Colors.grey[200]!, Colors.white],
        radius: 0.95,
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
    canvas.drawCircle(center, size.width / 2, bgPaint);

    // Draw faint reference circles
    final circlePaint = Paint()
      ..color = brightness == Brightness.dark ? Colors.white12 : Colors.black12
      ..style = PaintingStyle.stroke;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, circlePaint);
    }

    // Draw numbers
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * pi - pi / 2;
      final textPainter = TextPainter(
        text: TextSpan(
          text: dartboardNumbers[i].toString(),
          style: TextStyle(
            fontSize: 12,
            color: brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tx = center.dx + (radius + 18) * cos(angle) - textPainter.width / 2;
      final ty = center.dy + (radius + 18) * sin(angle) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(tx, ty));
    }

    // Draw hit polygons (spider-web)
    final Path path = Path();
    bool hasData = false;
    final safeMaxHits = maxHits == 0 ? 1 : maxHits;
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * pi - pi / 2;
      final num = dartboardNumbers[i];
      final hits = hitHeatmap[num] ?? 0;
      if (hits > 0) hasData = true;
      final hitRadius = radius * (hits / safeMaxHits);
      final x = center.dx + hitRadius * cos(angle);
      final y = center.dy + hitRadius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    if (hasData) {
      final Paint sectorPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      final Paint borderPaint = Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawPath(path, sectorPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}