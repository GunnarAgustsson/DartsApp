import 'package:flutter/material.dart';
import 'dart:math' as math;

class InteractiveDartboard extends StatefulWidget {
  final double size;
  final Set<String> highlightedAreas;
  final Function(String)? onAreaTapped;
  final Color? highlightColor;
  final bool interactive;

  const InteractiveDartboard({
    super.key,
    this.size = 300,
    this.highlightedAreas = const {},
    this.onAreaTapped,
    this.highlightColor,
    this.interactive = true,
  });

  @override
  State<InteractiveDartboard> createState() => _InteractiveDartboardState();
}

class _InteractiveDartboardState extends State<InteractiveDartboard> {
  String? hoveredArea;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: SizedBox(
          width: widget.size + 40, // Add extra space for numbers that extend beyond dartboard
          height: widget.size + 40, // Add extra space for numbers that extend beyond dartboard
          child: GestureDetector(
            onTapDown: widget.interactive ? _handleTap : null,
            child: MouseRegion(
              onHover: widget.interactive ? _handleHover : null,
              onExit: widget.interactive ? (_) => setState(() => hoveredArea = null) : null,
              child: CustomPaint(
                size: Size(widget.size + 40, widget.size + 40),
                painter: DartboardPainter(
                  highlightedAreas: widget.highlightedAreas,
                  hoveredArea: hoveredArea,
                  highlightColor: widget.highlightColor ?? Colors.orange,
                  isDarkMode: isDarkMode,
                  dartboardSize: widget.size,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    final area = _getAreaFromPosition(details.localPosition);
    if (area != null && widget.onAreaTapped != null) {
      widget.onAreaTapped!(area);
    }
  }

  void _handleHover(PointerEvent event) {
    final area = _getAreaFromPosition(event.localPosition);
    if (area != hoveredArea) {
      setState(() => hoveredArea = area);
    }
  }

  String? _getAreaFromPosition(Offset position) {
    final center = Offset((widget.size + 40) / 2, (widget.size + 40) / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = widget.size / 2;

    // Convert to angle (0-360 degrees, with 0° at top)
    double angle = math.atan2(dx, -dy) * 180 / math.pi;
    if (angle < 0) angle += 360;

    // Dartboard number sequence starting from top (20)
    const numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
    
    // Simple segment calculation: each segment is 18° wide
    int segmentIndex = (angle / 18).round() % 20;
    int number = numbers[segmentIndex];

    // Define dartboard regions (as percentages of radius)
    final bullRadius = radius * 0.05;
    final innerBullRadius = radius * 0.08;
    final tripleInnerRadius = radius * 0.65;
    final tripleOuterRadius = radius * 0.73;
    final outerSingleRadius = radius * 0.9;
    final doubleInnerRadius = radius * 0.95;

    if (distance <= bullRadius) {
      return 'BULL';
    } else if (distance <= innerBullRadius) {
      return '25';
    } else if (distance <= tripleInnerRadius) {
      return '${number}I'; // Inner single (from 25 to triple ring)
    } else if (distance <= tripleOuterRadius) {
      return 'T$number'; // Triple
    } else if (distance <= outerSingleRadius) {
      return '${number}O'; // Outer single
    } else if (distance <= doubleInnerRadius) {
      return 'D$number'; // Double
    } else if (distance <= radius) {
      return '${number}O'; // Single (outer edge)
    }

    return null;
  }
}

class DartboardPainter extends CustomPainter {
  final Set<String> highlightedAreas;
  final String? hoveredArea;
  final Color highlightColor;
  final bool isDarkMode;
  final double dartboardSize;

  DartboardPainter({
    required this.highlightedAreas,
    this.hoveredArea,
    required this.highlightColor,
    required this.isDarkMode,
    required this.dartboardSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = dartboardSize / 2; // Use dartboardSize instead of canvas size

    // Define dartboard colors
    final blackPaint = Paint()..color = Colors.black;
    final whitePaint = Paint()..color = Colors.white;
    final redPaint = Paint()..color = Colors.red;
    final greenPaint = Paint()..color = Colors.green;
    final highlightPaint = Paint()..color = const Color(0xFFFF8C00).withOpacity(0.9); // More opaque orange
    final hoverPaint = Paint()..color = const Color(0xFFFF8C00).withOpacity(0.5);

    // Dartboard number sequence starting from top (20)
    const numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

    // Draw outer border
    canvas.drawCircle(center, radius, blackPaint);
    canvas.drawCircle(center, radius * 0.98, whitePaint);

    // Draw each segment
    for (int i = 0; i < 20; i++) {
      final number = numbers[i];
      // Calculate angles for segment boundaries (not centers)
      // Subtract 90° to align with hit detection coordinate system (0° = top)
      final startAngle = (i * 18 - 9 - 180) * math.pi / 180;
      final endAngle = (i * 18 + 9 - 180) * math.pi / 180;

      // Determine colors for this segment
      final isEvenSegment = i % 2 == 0;
      final singleColor = isEvenSegment ? whitePaint : blackPaint;
      final tripleColor = isEvenSegment ? redPaint : greenPaint;
      final doubleColor = isEvenSegment ? redPaint : greenPaint;

      // Draw double ring
      _drawSegment(canvas, center, radius * 0.9, radius * 0.95, startAngle, endAngle, doubleColor);
      if (_shouldHighlight('D$number') || _shouldHighlight('$number')) {
        _drawSegment(canvas, center, radius * 0.9, radius * 0.95, startAngle, endAngle, highlightPaint);
      }
      if (hoveredArea == 'D$number') {
        _drawSegment(canvas, center, radius * 0.9, radius * 0.95, startAngle, endAngle, hoverPaint);
      }

      // Draw outer single ring
      _drawSegment(canvas, center, radius * 0.73, radius * 0.9, startAngle, endAngle, singleColor);
      if (_shouldHighlight('${number}O') || _shouldHighlight('$number') || _shouldHighlight('S$number')) {
        _drawSegment(canvas, center, radius * 0.73, radius * 0.9, startAngle, endAngle, highlightPaint);
      }
      if (hoveredArea == '${number}O') {
        _drawSegment(canvas, center, radius * 0.73, radius * 0.9, startAngle, endAngle, hoverPaint);
      }

      // Draw triple ring
      _drawSegment(canvas, center, radius * 0.65, radius * 0.73, startAngle, endAngle, tripleColor);
      if (_shouldHighlight('T$number') || _shouldHighlight('$number')) {
        _drawSegment(canvas, center, radius * 0.65, radius * 0.73, startAngle, endAngle, highlightPaint);
      }
      if (hoveredArea == 'T$number') {
        _drawSegment(canvas, center, radius * 0.65, radius * 0.73, startAngle, endAngle, hoverPaint);
      }

      // Draw inner single area (from 25 ring to triple ring)
      _drawSegment(canvas, center, radius * 0.08, radius * 0.65, startAngle, endAngle, singleColor);
      if (_shouldHighlight('${number}I') || _shouldHighlight('$number') || _shouldHighlight('S$number')) {
        _drawSegment(canvas, center, radius * 0.08, radius * 0.65, startAngle, endAngle, highlightPaint);
      }
      if (hoveredArea == '${number}I') {
        _drawSegment(canvas, center, radius * 0.08, radius * 0.65, startAngle, endAngle, hoverPaint);
      }
    }

    // Draw bull rings
    canvas.drawCircle(center, radius * 0.08, greenPaint); // Outer bull (25)
    if (_shouldHighlight('25')) {
      canvas.drawCircle(center, radius * 0.08, highlightPaint);
    }
    if (hoveredArea == '25') {
      canvas.drawCircle(center, radius * 0.08, hoverPaint);
    }

    canvas.drawCircle(center, radius * 0.05, redPaint); // Inner bull (50)
    if (_shouldHighlight('BULL') || _shouldHighlight('50')) {
      canvas.drawCircle(center, radius * 0.05, highlightPaint);
    }
    if (hoveredArea == 'BULL') {
      canvas.drawCircle(center, radius * 0.05, hoverPaint);
    }

    // Draw ring dividers with wider lines
    final ringPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3 // Wider outlines
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * 0.65, ringPaint);
    canvas.drawCircle(center, radius * 0.73, ringPaint);
    canvas.drawCircle(center, radius * 0.9, ringPaint);
    canvas.drawCircle(center, radius * 0.95, ringPaint);

    // Draw numbers
    _drawNumbers(canvas, center, radius);
  }

  bool _shouldHighlight(String area) {
    return highlightedAreas.contains(area);
  }

  void _drawSegment(Canvas canvas, Offset center, double innerRadius, double outerRadius, 
                   double startAngle, double endAngle, Paint paint) {
    final path = Path();
    
    // Start at inner radius
    path.moveTo(
      center.dx + math.cos(startAngle + math.pi / 2) * innerRadius,
      center.dy + math.sin(startAngle + math.pi / 2) * innerRadius,
    );
    
    // Line to outer radius
    path.lineTo(
      center.dx + math.cos(startAngle + math.pi / 2) * outerRadius,
      center.dy + math.sin(startAngle + math.pi / 2) * outerRadius,
    );
    
    // Arc along outer radius
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle + math.pi / 2,
      endAngle - startAngle,
      false,
    );
    
    // Line back to inner radius
    path.lineTo(
      center.dx + math.cos(endAngle + math.pi / 2) * innerRadius,
      center.dy + math.sin(endAngle + math.pi / 2) * innerRadius,
    );
    
    // Arc along inner radius (reverse direction)
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      endAngle + math.pi / 2,
      startAngle - endAngle,
      false,
    );
    
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawNumbers(Canvas canvas, Offset center, double radius) {
    const numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
    
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < 20; i++) {
      final number = numbers[i];
      // Position numbers at segment centers (each segment is 18 degrees, centered at i * 18)
      // Subtract 90° to align with hit detection coordinate system (0° = top)
      final angle = (i * 18 - 90) * math.pi / 180;
      
      textPainter.text = TextSpan(
        text: number.toString(),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            // Add contrasting shadow for better visibility
            Shadow(
              offset: Offset(1.0, 1.0),
              blurRadius: 2.0,
              color: isDarkMode ? Colors.black : Colors.white,
            ),
            Shadow(
              offset: Offset(-1.0, -1.0),
              blurRadius: 2.0,
              color: isDarkMode ? Colors.black : Colors.white,
            ),
            Shadow(
              offset: Offset(1.0, -1.0),
              blurRadius: 2.0,
              color: isDarkMode ? Colors.black : Colors.white,
            ),
            Shadow(
              offset: Offset(-1.0, 1.0),
              blurRadius: 2.0,
              color: isDarkMode ? Colors.black : Colors.white,
            ),
          ],
        ),
      );
      
      textPainter.layout();
      
      final x = center.dx + math.cos(angle) * radius * 1.05 - textPainter.width / 2;
      final y = center.dy + math.sin(angle) * radius * 1.05 - textPainter.height / 2;
      
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(DartboardPainter oldDelegate) {
    return oldDelegate.highlightedAreas != highlightedAreas ||
           oldDelegate.hoveredArea != hoveredArea ||
           oldDelegate.highlightColor != highlightColor;
  }
}
