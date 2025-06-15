import 'package:flutter/material.dart';
import 'package:dars_scoring_app/theme/index.dart';

/// Describes the size variants of the score button
enum ScoreButtonSize { small, medium, large }

/// A button used for scoring in the dart game
class ScoreButton extends StatelessWidget {
  /// The numeric value of this button
  final int value;
  
  /// Optional custom label (defaults to value as string)
  final String? label;
  
  /// Whether the button is disabled
  final bool disabled;
  
  /// Size of the button text (if null uses theme default)
  final double? fontSize;
  
  /// Button size variant
  final ScoreButtonSize size;
  
  /// Button click callback
  final VoidCallback onPressed;
  
  /// Whether this is a high-value button (uses accent styling)
  final bool isHighValue;
  const ScoreButton({
    super.key,
    required this.value,
    this.label,
    this.disabled = false,
    this.fontSize,
    this.size = ScoreButtonSize.medium,
    this.isHighValue = false,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final heightScale = size.height / 800; // Base scale on a height of 800
    
    // Determine padding based on size
    EdgeInsets padding;
    double? buttonFontSize;
      switch (this.size) {
      case ScoreButtonSize.small:
        padding = EdgeInsets.symmetric(
          vertical: AppDimensions.paddingXS * heightScale,
          horizontal: AppDimensions.paddingS * heightScale
        );
        buttonFontSize = fontSize ?? (12 * heightScale);
      case ScoreButtonSize.medium:
        padding = EdgeInsets.symmetric(
          vertical: AppDimensions.paddingS * heightScale,
          horizontal: AppDimensions.paddingM * heightScale
        );
        buttonFontSize = fontSize ?? (14 * heightScale);
      case ScoreButtonSize.large:
        padding = EdgeInsets.symmetric(
          vertical: AppDimensions.paddingM * heightScale,
          horizontal: AppDimensions.paddingL * heightScale
        );
        buttonFontSize = fontSize ?? (18 * heightScale);
    }
    
    // Determine color based on high value status
    final backgroundColor = isHighValue 
        ? theme.colorScheme.secondary 
        : theme.colorScheme.primary;
        
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: padding,
        textStyle: TextStyle(fontSize: buttonFontSize),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        elevation: AppDimensions.elevationS,
      ),
      onPressed: disabled ? null : onPressed,
      child: Text(
        label ?? '$value',
        style: TextStyle(
          fontSize: buttonFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}