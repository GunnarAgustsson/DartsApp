import 'package:flutter/material.dart';

/// Describes the size variants of the score button
enum ScoreButtonSize { small, medium, large, custom }

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
  
  /// Custom button size (only used if size is custom)
  final Size? customSize;
  
  /// Button click callback
  final VoidCallback onPressed;
  
  /// Whether this is a high-value button (uses accent styling)
  final bool isHighValue;

  /// Optional custom background color
  final Color? backgroundColor;
  
  /// Optional custom foreground (text) color
  final Color? foregroundColor;

  /// Optional border radius override
  final double? borderRadius;

  const ScoreButton({
    super.key,
    required this.value,
    this.label,
    this.disabled = false,
    this.fontSize,
    this.size = ScoreButtonSize.medium,
    this.customSize,
    this.isHighValue = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final smallerDimension = screenSize.width < screenSize.height ? 
        screenSize.width : screenSize.height;
    
    // Dynamically size button based on screen dimensions
    double buttonWidth;
    double buttonHeight;
    double? buttonFontSize;
    
    switch (size) {
      case ScoreButtonSize.small:
        buttonWidth = smallerDimension * 0.1;
        buttonHeight = smallerDimension * 0.1;
        buttonFontSize = fontSize ?? (smallerDimension * 0.032);
        break;
      case ScoreButtonSize.medium:
        buttonWidth = smallerDimension * 0.12;
        buttonHeight = smallerDimension * 0.12;
        buttonFontSize = fontSize ?? (smallerDimension * 0.036);
        break;
      case ScoreButtonSize.large:
        buttonWidth = smallerDimension * 0.14;
        buttonHeight = smallerDimension * 0.14;
        buttonFontSize = fontSize ?? (smallerDimension * 0.04);
        break;
      case ScoreButtonSize.custom:
        buttonWidth = customSize?.width ?? smallerDimension * 0.1;
        buttonHeight = customSize?.height ?? smallerDimension * 0.1;
        buttonFontSize = fontSize ?? (buttonHeight * 0.4);
        break;
    }
    
    // Determine colors based on button type
    Color bgColor = isHighValue ? theme.colorScheme.secondary : theme.colorScheme.primary;
    Color fgColor = isHighValue ? theme.colorScheme.onSecondary : theme.colorScheme.onPrimary;

    // Override with custom colors if provided
    if (backgroundColor != null) bgColor = backgroundColor!;
    if (foregroundColor != null) fgColor = foregroundColor!;
    
    // Use custom radius if provided, otherwise default to very rounded
    final radius = borderRadius ?? (buttonHeight / 2); // Default to circle
    
    // For standard number buttons (1-20), force perfect circles
    final bool isNumberButton = (value >= 1 && value <= 20);
    final finalRadius = isNumberButton ? buttonHeight / 2 : radius;
    
    return SizedBox(
      width: buttonWidth, 
      height: buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: EdgeInsets.zero, // Remove padding to ensure proper sizing
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(finalRadius),
          ),
          elevation: 2,
          minimumSize: Size.zero, // Allow the button to shrink
        ),
        onPressed: disabled ? null : onPressed,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.all(smallerDimension * 0.01),
              child: Text(
                label ?? '$value',
                style: TextStyle(
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}