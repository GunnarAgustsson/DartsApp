import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
import 'score_button.dart';

/// Callback for when a score is made with label
typedef OnScoreWithLabelCallback = void Function(int score, String label);

/// Callback for when undo is pressed
typedef OnUndoCallback = void Function();

/// Configuration for the scoring buttons widget
class ScoringButtonsConfig {

  const ScoringButtonsConfig({
    this.showMultipliers = true,
    this.show25Button = true,
    this.showBullButton = true,
    this.showMissButton = true,
    this.showUndoButton = true,
    this.disabled = false,
  });
  /// Whether to show multiplier buttons (x2, x3)
  final bool showMultipliers;
  
  /// Whether to show the 25 button
  final bool show25Button;
  
  /// Whether to show the Bull (50) button
  final bool showBullButton;
  
  /// Whether to show the Miss button
  final bool showMissButton;
  
  /// Whether to show the Undo button
  final bool showUndoButton;
  
  /// Whether the interface is disabled
  final bool disabled;
}

/// A reusable widget that provides all scoring functionality for dart games
/// Includes number buttons (1-20), multipliers (x2, x3), special buttons (25, Bull), and action buttons (Miss, Undo)
class ScoringButtons extends StatefulWidget {

  const ScoringButtons({
    super.key,
    required this.config,
    required this.onScore,
    this.onUndo,
  });
  /// Configuration for what buttons to show and their states
  final ScoringButtonsConfig config;
  
  /// Callback when a score is made - receives the calculated score and the label (e.g., "D20", "T15")
  final void Function(int score, String label) onScore;
  
  /// Callback when undo is pressed
  final OnUndoCallback? onUndo;

  @override
  State<ScoringButtons> createState() => _ScoringButtonsState();
}

class _ScoringButtonsState extends State<ScoringButtons> {
  int _currentMultiplier = 1;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    return Column(
      children: [
        // Multiplier buttons (if enabled)
        if (widget.config.showMultipliers) ...[
          SizedBox(
            height: isLandscape ? 55 : size.height * 0.07,
            child: _buildMultiplierButtons(context),
          ),
          const SizedBox(height: AppDimensions.marginM),
        ],
        
        // Main number grid
        Expanded(
          flex: 3,
          child: _buildNumberGrid(context),
        ),
        
        const SizedBox(height: AppDimensions.marginM),
        
        // Special action buttons
        _buildSpecialActions(context),
      ],
    );
  }

  /// Build the multiplier buttons (x2, x3)
  Widget _buildMultiplierButtons(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = widget.config.disabled;

    Widget buildButton(int multiplier, Color color, Color containerColor) {
      final isSelected = _currentMultiplier == multiplier;
      return Expanded(
        flex: 2,
        child: SizedBox(
          height: 55,
          child: isSelected
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.7),
                        color,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                      ),
                    ),
                    onPressed: isDisabled ? null : () => setState(() => _currentMultiplier = _currentMultiplier == multiplier ? 1 : multiplier),
                    child: Text(
                      'x$multiplier',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    ),
                  ),
                  onPressed: isDisabled ? null : () => setState(() => _currentMultiplier = _currentMultiplier == multiplier ? 1 : multiplier),
                  child: Text('x$multiplier', style: const TextStyle(fontSize: 18)),
                ),
        ),
      );
    }

    return Row(
      children: [
        const Spacer(),
        buildButton(2, theme.colorScheme.secondary, theme.colorScheme.secondaryContainer),
        const SizedBox(width: AppDimensions.marginS),
        buildButton(3, theme.colorScheme.tertiary, theme.colorScheme.tertiaryContainer),
        const Spacer(),
      ],
    );
  }

  /// Build the number grid (always 1-20 in sequential order)
  Widget _buildNumberGrid(BuildContext context) {
    // Always use sequential 1-20 order, ignore customNumbers
    final numbers = List.generate(20, (index) => index + 1);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 5;
        final mainAxisCount = (numbers.length / crossAxisCount).ceil();
        const hSpacing = AppDimensions.marginS;
        const vSpacing = AppDimensions.marginS;

        final buttonWidth = (constraints.maxWidth - (crossAxisCount - 1) * hSpacing) / crossAxisCount;
        final buttonHeight = (constraints.maxHeight - (mainAxisCount - 1) * vSpacing) / mainAxisCount;
        final side = min(buttonWidth, buttonHeight);
        final numberButtonSize = Size(side, side);

        List<Widget> gridRows = [];
        
        for (int row = 0; row < mainAxisCount; row++) {
          List<Widget> rowButtons = [];
          for (int col = 0; col < crossAxisCount; col++) {
            final index = row * crossAxisCount + col;
            if (index < numbers.length) {
              final value = numbers[index];
              final score = value * _currentMultiplier;
              
              // Generate label with multiplier prefix for callback (e.g., "D20", "T15")
              String label = value.toString();
              if (_currentMultiplier > 1) {
                final multiplierPrefix = _currentMultiplier == 2 ? 'D' : 'T';
                label = '$multiplierPrefix$value';
              }
              
              rowButtons.add(
                Expanded(
                  child: ScoreButton(
                    value: value,
                    label: value.toString(), // Always show just the number on the button
                    onPressed: () {
                      widget.onScore(score, label); // Pass the full label to callback
                      // Reset multiplier after scoring
                      if (_currentMultiplier > 1) {
                        setState(() => _currentMultiplier = 1);
                      }
                    },
                    disabled: widget.config.disabled,
                    size: ScoreButtonSize.custom,
                    customSize: numberButtonSize,
                  ),
                ),
              );
            } else {
              // Empty space for incomplete rows
              rowButtons.add(const Expanded(child: SizedBox()));
            }
            
            if (col < crossAxisCount - 1) {
              rowButtons.add(const SizedBox(width: hSpacing));
            }
          }
          
          gridRows.add(Expanded(child: Row(children: rowButtons)));
          if (row < mainAxisCount - 1) {
            gridRows.add(const SizedBox(height: vSpacing));
          }
        }

        return Column(children: gridRows);
      },
    );
  }

  /// Build special action buttons (25, Bull, Miss, Undo)
  Widget _buildSpecialActions(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final textScaler = MediaQuery.of(context).textScaler;
    final textScaleFactor = textScaler.scale(1.0);
    
    // More aggressive responsiveness for small scaling
    final buttonHeight = isLandscape 
        ? max(40.0, size.height * 0.075) 
        : max(45.0, size.height * 0.055);
    
    // Responsive font size with text scale factor consideration
    final baseFontSize = isLandscape 
        ? min(14.0, size.width * 0.018) 
        : min(16.0, size.width * 0.035);
    final fontSize = baseFontSize / max(1.0, textScaleFactor * 0.8);
    
    // Responsive icon size with scale factor
    final baseIconSize = isLandscape 
        ? min(16.0, size.width * 0.02) 
        : min(18.0, size.width * 0.04);
    final iconSize = baseIconSize / max(1.0, textScaleFactor * 0.8);
    
    // Tighter spacing for small scaling
    final spacing = isLandscape || textScaleFactor < 1.0
        ? AppDimensions.marginXS / 2
        : AppDimensions.marginXS;

    List<Widget> buttons = [];

    // 25 Button
    if (widget.config.show25Button) {
      final score25 = 25 * _currentMultiplier;
      String label25 = '25';
      if (_currentMultiplier > 1) {
        final multiplierPrefix = _currentMultiplier == 2 ? 'D' : 'T';
        label25 = '${multiplierPrefix}25';
      }
      
      buttons.add(
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8.0 : 12.0,
                  vertical: 4.0,
                ),
              ),
              onPressed: widget.config.disabled ? null : () {
                widget.onScore(score25, label25); // Pass full label to callback
                // Reset multiplier after scoring
                if (_currentMultiplier > 1) {
                  setState(() => _currentMultiplier = 1);
                }
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '25', // Always show just the number on the button
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Bull Button (always 50, not affected by multiplier)
    if (widget.config.showBullButton) {
      if (buttons.isNotEmpty) buttons.add(SizedBox(width: spacing));
      buttons.add(
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8.0 : 12.0,
                  vertical: 4.0,
                ),
              ),
              onPressed: widget.config.disabled ? null : () {
                widget.onScore(50, 'Bull'); // Bull is always 50, regardless of multiplier
                // Reset multiplier after scoring
                if (_currentMultiplier > 1) {
                  setState(() => _currentMultiplier = 1);
                }
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Bull',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Miss Button
    if (widget.config.showMissButton) {
      if (buttons.isNotEmpty) buttons.add(SizedBox(width: spacing));
      buttons.add(
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: textScaleFactor < 1.0 || size.width < 400
                ? // Compact version for very small screens
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error, width: 2),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 2.0,
                      ),
                    ),
                    onPressed: widget.config.disabled ? null : () => widget.onScore(0, 'Miss'),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel_outlined, size: iconSize),
                          const SizedBox(height: 1),
                          Text(
                            'Miss',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize * 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : // Regular version with icon and label
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error, width: 2),
                      shape: const StadiumBorder(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 6.0 : 8.0,
                        vertical: 4.0,
                      ),
                    ),
                    onPressed: widget.config.disabled ? null : () => widget.onScore(0, 'Miss'),
                    icon: Icon(Icons.cancel_outlined, size: iconSize),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Miss',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize * 0.9,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    // Undo Button
    if (widget.config.showUndoButton) {
      if (buttons.isNotEmpty) buttons.add(SizedBox(width: spacing));
      buttons.add(
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: textScaleFactor < 1.0 || size.width < 400
                ? // Compact version for very small screens
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error, width: 2),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 2.0,
                      ),
                    ),
                    onPressed: widget.config.disabled ? null : widget.onUndo,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.undo, size: iconSize),
                          const SizedBox(height: 1),
                          Text(
                            'Undo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize * 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : // Regular version with icon and label
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error, width: 2),
                      shape: const StadiumBorder(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 6.0 : 8.0,
                        vertical: 4.0,
                      ),
                    ),
                    onPressed: widget.config.disabled ? null : widget.onUndo,
                    icon: Icon(Icons.undo, size: iconSize),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Undo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize * 0.9,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    return Row(children: buttons);
  }
}
