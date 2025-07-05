import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/killer_player.dart';

class InteractiveDartboard extends StatefulWidget {
  final double size;
  final Set<String> highlightedAreas;
  final List<KillerPlayerTerritory> killerTerritories;
  final Function(String)? onAreaTapped;
  final Color? highlightColor;
  final bool interactive;

  const InteractiveDartboard({
    super.key,
    this.size = 300,
    this.highlightedAreas = const {},
    this.killerTerritories = const [],
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
                  killerTerritories: widget.killerTerritories,
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
  final List<KillerPlayerTerritory> killerTerritories;
  final String? hoveredArea;
  final Color highlightColor;
  final bool isDarkMode;
  final double dartboardSize;

  DartboardPainter({
    required this.highlightedAreas,
    this.killerTerritories = const [],
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

    // Draw killer territories
    _drawKillerTerritories(canvas, center, radius);

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

  /// Draws all killer territories with proper visual effects
  void _drawKillerTerritories(Canvas canvas, Offset center, double radius) {
    for (final territory in killerTerritories) {
      for (final area in territory.areas) {
        _drawKillerHighlight(canvas, center, radius, area, territory);
      }
    }
    
    // Draw territory borders only at boundaries for clean separation
    _drawTerritoryBorders(canvas, center, radius);
  }

  /// Draws highlight for a single territory area with health-based effects
  void _drawKillerHighlight(Canvas canvas, Offset center, double radius, String area, KillerPlayerTerritory territory) {
    // Calculate enhanced opacity with pulse effect for current player
    final baseOpacity = territory.highlightOpacity;
    final pulseBoost = territory.isCurrentPlayer ? (territory.pulseIntensity * 0.3) : 0.0;
    final finalOpacity = (baseOpacity + pulseBoost).clamp(0.0, 1.0);

    // Special effects for different player states
    if (territory.isEliminated) {
      // Faded gray effect for eliminated players
      final eliminatedPaint = Paint()
        ..color = Colors.grey.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      _drawAreaHighlight(canvas, center, radius, area, eliminatedPaint);
      return;
    }

    // Enhanced glow effect for killers
    if (territory.isKiller) {
      final glowIntensity = territory.isCurrentPlayer ? (0.5 + territory.pulseIntensity * 0.3) : 0.4;
      final glowPaint = Paint()
        ..color = territory.playerColor.withOpacity(glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4.0);
      
      // Draw killer glow effect
      _drawAreaHighlight(canvas, center, radius, area, glowPaint);
    }

    // Draw health-based fill
    if (territory.borderOnly) {
      // Only border for 0 health players - thick and visible
      final borderPaint = Paint()
        ..color = territory.playerColor
        ..strokeWidth = 5.0
        ..style = PaintingStyle.stroke;
      _drawAreaHighlight(canvas, center, radius, area, borderPaint);
    } else {
      // Partial fill based on health percentage
      final fillPaint = Paint()
        ..color = territory.playerColor.withOpacity(finalOpacity * territory.fillPercentage)
        ..style = PaintingStyle.fill;
      _drawAreaHighlight(canvas, center, radius, area, fillPaint);
    }
  }

  /// Draws clean borders between different player territories
  void _drawTerritoryBorders(Canvas canvas, Offset center, double radius) {
    for (final territory in killerTerritories) {
      if (territory.areas.isEmpty) continue;
      
      // Parse all numbers in this territory
      List<int> numbers = territory.areas
          .map((area) => int.tryParse(area))
          .where((num) => num != null && num >= 1 && num <= 20)
          .cast<int>()
          .toList();
      
      if (numbers.isEmpty) continue;
      
      // Find territory boundaries for clean border drawing
      const dartboardNumbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
      
      final borderPaint = Paint()
        ..color = territory.playerColor
        ..strokeWidth = territory.isKiller ? 6.0 : 4.0
        ..style = PaintingStyle.stroke;
        
      for (final number in numbers) {
        final segmentIndex = dartboardNumbers.indexOf(number);
        if (segmentIndex == -1) continue;
        
        // Check if this segment is at a territory boundary
        final prevIndex = (segmentIndex - 1 + 20) % 20;
        final nextIndex = (segmentIndex + 1) % 20;
        final prevNumber = dartboardNumbers[prevIndex];
        final nextNumber = dartboardNumbers[nextIndex];
        
        final isLeftBoundary = !numbers.contains(prevNumber);
        final isRightBoundary = !numbers.contains(nextNumber);
        
        if (isLeftBoundary || isRightBoundary) {
          final startAngle = (segmentIndex * 18 - 9 - 180) * math.pi / 180;
          final endAngle = (segmentIndex * 18 + 9 - 180) * math.pi / 180;
          
          if (isLeftBoundary) {
            _drawSegmentBorder(canvas, center, radius, startAngle, borderPaint);
          }
          if (isRightBoundary) {
            _drawSegmentBorder(canvas, center, radius, endAngle, borderPaint);
          }
        }
      }
    }
  }

  /// Draws a radial border line for territory separation
  void _drawSegmentBorder(Canvas canvas, Offset center, double radius, double angle, Paint paint) {
    final innerRadius = radius * 0.08;
    final outerRadius = radius * 0.95;
    
    final innerPoint = Offset(
      center.dx + innerRadius * math.cos(angle),
      center.dy + innerRadius * math.sin(angle),
    );
    final outerPoint = Offset(
      center.dx + outerRadius * math.cos(angle),
      center.dy + outerRadius * math.sin(angle),
    );
    
    canvas.drawLine(innerPoint, outerPoint, paint);
  }

  /// Draws highlight for a specific dartboard area
  void _drawAreaHighlight(Canvas canvas, Offset center, double radius, String area, Paint paint) {
    // Handle bull areas
    if (area == 'BULL') {
      canvas.drawCircle(center, radius * 0.05, paint);
      return;
    } else if (area == '25') {
      canvas.drawCircle(center, radius * 0.08, paint);
      return;
    }
    
    // Parse number for regular dartboard segments
    final number = int.tryParse(area);
    if (number != null && number >= 1 && number <= 20) {
      const numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
      final segmentIndex = numbers.indexOf(number);
      
      if (segmentIndex != -1) {
        final startAngle = (segmentIndex * 18 - 9 - 180) * math.pi / 180;
        final endAngle = (segmentIndex * 18 + 9 - 180) * math.pi / 180;
        
        // Highlight entire number section - all rings
        _drawSegment(canvas, center, radius * 0.08, radius * 0.65, startAngle, endAngle, paint);
        _drawSegment(canvas, center, radius * 0.65, radius * 0.73, startAngle, endAngle, paint);
        _drawSegment(canvas, center, radius * 0.73, radius * 0.9, startAngle, endAngle, paint);
        _drawSegment(canvas, center, radius * 0.9, radius * 0.95, startAngle, endAngle, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DartboardPainter oldDelegate) {
    return oldDelegate.highlightedAreas != highlightedAreas ||
           oldDelegate.killerTerritories != killerTerritories ||
           oldDelegate.hoveredArea != hoveredArea ||
           oldDelegate.highlightColor != highlightColor;
  }
}
