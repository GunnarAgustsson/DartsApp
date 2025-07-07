import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/index.dart';

/// Animation types for game overlays
enum GameOverlayType {
  // Traditional/Cricket game events
  bust,
  turnChange,
  
  // Donkey game events
  letterReceived,
  playerEliminated,
  
  // Killer game events
  playerBecomesKiller,
  killerEliminated,
  killerTurnChange,
  
  // General events
  gameWon,
  gameOver,
}

/// Defines different size variants for the overlay
enum OverlaySize { small, medium, large }

/// A universal widget that shows animated overlays for game events across all game modes
class GameOverlayAnimation extends StatefulWidget {
  const GameOverlayAnimation({
    super.key,
    required this.overlayType,
    required this.isVisible,
    this.playerName = '',
    this.nextPlayerName = '',
    this.lastTurnPoints = '',
    this.lastTurnLabels = '',
    this.letterReceivedLetters = '',
    this.additionalInfo = '',
    this.bgColor,
    this.size = OverlaySize.large,
    this.animationDuration = const Duration(milliseconds: 300),
    this.displayDuration = const Duration(seconds: 2),
    this.onAnimationComplete,
    this.onTapToClose,
  });

  /// The type of overlay to show
  final GameOverlayType overlayType;
  
  /// Whether the overlay is visible
  final bool isVisible;
  
  /// The primary player name for the event
  final String playerName;
  
  /// Name of the next player (for turn changes)
  final String nextPlayerName;
  
  /// Points scored in the last turn
  final String lastTurnPoints;
  
  /// Labels for darts thrown in the last turn
  final String lastTurnLabels;
  
  /// Letters the player now has (for Donkey game)
  final String letterReceivedLetters;
  
  /// Additional info text
  final String additionalInfo;
  
  /// Background color for the overlay
  final Color? bgColor;
  
  /// Size variant for the overlay
  final OverlaySize size;
  
  /// Animation duration for this overlay
  final Duration animationDuration;
  
  /// How long to display the overlay before auto-hiding
  final Duration displayDuration;
  
  /// Callback when animation completes
  final VoidCallback? onAnimationComplete;
  
  /// Callback when overlay is tapped to close early
  final VoidCallback? onTapToClose;

  @override
  State<GameOverlayAnimation> createState() => _GameOverlayAnimationState();
}

class _GameOverlayAnimationState extends State<GameOverlayAnimation>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: Duration(milliseconds: widget.animationDuration.inMilliseconds + 100),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _colorAnimation = ColorTween(
      begin: _getBackgroundColor().withOpacity(0.0),
      end: _getBackgroundColor(),
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GameOverlayAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible && !oldWidget.isVisible) {
      _showAnimation();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _hideAnimation();
    }
  }

  void _showAnimation() async {
    _fadeController.forward();
    _scaleController.forward();
    
    // Auto-hide after specified duration
    await Future.delayed(widget.displayDuration);
    if (mounted && widget.isVisible) {
      _hideAnimation();
    }
  }

  void _hideAnimation() async {
    await _scaleController.reverse();
    await _fadeController.reverse();
    
    if (mounted) {
      widget.onAnimationComplete?.call();
    }
  }

  void _handleTap() {
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    // Close animation early
    widget.onTapToClose?.call();
    _hideAnimation();
  }

  Color _getBackgroundColor() {
    if (widget.bgColor != null) return widget.bgColor!;
    
    switch (widget.overlayType) {
      case GameOverlayType.bust:
      case GameOverlayType.letterReceived:
      case GameOverlayType.playerEliminated:
      case GameOverlayType.killerEliminated:
        return AppColors.bustOverlayRed;
      
      case GameOverlayType.playerBecomesKiller:
        return Colors.orange.withOpacity(0.9);
      
      case GameOverlayType.gameWon:
        return Colors.green.withOpacity(0.9);
      
      case GameOverlayType.turnChange:
      case GameOverlayType.killerTurnChange:
      case GameOverlayType.gameOver:
        return AppColors.turnChangeBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    // Calculate font sizes based on size variant
    double primaryFontSize = 72;
    double secondaryFontSize = 36;
    double tertiaryFontSize = 28;
    
    switch (widget.size) {
      case OverlaySize.small:
        primaryFontSize = 48;
        secondaryFontSize = 24;
        tertiaryFontSize = 18;
        break;
      case OverlaySize.medium:
        primaryFontSize = 64;
        secondaryFontSize = 32;
        tertiaryFontSize = 24;
        break;
      case OverlaySize.large:
        primaryFontSize = 72;
        secondaryFontSize = 36;
        tertiaryFontSize = 28;
        break;
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_fadeController, _scaleController]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: GestureDetector(
              onTap: _handleTap,
              child: Container(
                color: Colors.black54, // Semi-transparent background
                child: Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _colorAnimation.value,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXL),
                      child: _buildContent(primaryFontSize, secondaryFontSize, tertiaryFontSize),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(double primaryFontSize, double secondaryFontSize, double tertiaryFontSize) {
    switch (widget.overlayType) {
      case GameOverlayType.bust:
        return Text(
          'BUST',
          style: AppTextStyles.bustOverlay().copyWith(
            fontSize: primaryFontSize,
          ),
        );

      case GameOverlayType.turnChange:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.lastTurnPoints.isNotEmpty) ...[
              Text(
                'Scored: ${widget.lastTurnPoints}',
                style: AppTextStyles.turnChangeOverlay().copyWith(
                  fontSize: secondaryFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8 * (secondaryFontSize / 40)),
            ],
            if (widget.lastTurnLabels.isNotEmpty) ...[
              Text(
                widget.lastTurnLabels,
                style: AppTextStyles.turnChangeOverlay().copyWith(
                  fontSize: tertiaryFontSize,
                  fontWeight: FontWeight.normal,
                ),
              ),
              SizedBox(height: 8 * (secondaryFontSize / 40)),
            ],
            Text(
              "It's ${widget.nextPlayerName}'s turn!",
              style: AppTextStyles.turnChangeOverlay().copyWith(
                fontSize: secondaryFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case GameOverlayType.letterReceived:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${widget.playerName} got a letter!',
              style: AppTextStyles.bustOverlay().copyWith(
                fontSize: secondaryFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * (secondaryFontSize / 40)),
            Text(
              'Letters: ${widget.letterReceivedLetters.split('').join('-')}',
              style: AppTextStyles.bustOverlay().copyWith(
                fontSize: tertiaryFontSize + 4,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        );

      case GameOverlayType.playerEliminated:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${widget.playerName} is eliminated!',
              style: AppTextStyles.bustOverlay().copyWith(
                fontSize: secondaryFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * (secondaryFontSize / 40)),
            Text(
              widget.additionalInfo.isNotEmpty 
                  ? widget.additionalInfo 
                  : '${widget.playerName} is a DONKEY! 🐴',
              style: AppTextStyles.bustOverlay().copyWith(
                fontSize: tertiaryFontSize + 4,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        );

      case GameOverlayType.playerBecomesKiller:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${widget.playerName}',
              style: TextStyle(
                color: Colors.white,
                fontSize: secondaryFontSize,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * (secondaryFontSize / 40)),
            Text(
              'IS NOW A KILLER!',
              style: TextStyle(
                color: Colors.white,
                fontSize: primaryFontSize * 0.8,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: const [
                  Shadow(
                    offset: Offset(3, 3),
                    blurRadius: 6,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12 * (secondaryFontSize / 40)),
            Text(
              '🎯 Can now eliminate other players! 🎯',
              style: TextStyle(
                color: Colors.white,
                fontSize: tertiaryFontSize,
                fontWeight: FontWeight.normal,
                shadows: const [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ],
        );

      case GameOverlayType.killerEliminated:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${widget.playerName}',
              style: AppTextStyles.bustOverlay().copyWith(
                fontSize: secondaryFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8 * (secondaryFontSize / 40)),
            Text(
              'HAS BEEN ELIMINATED!',
              style: AppTextStyles.bustOverlay().copyWith(
                fontSize: primaryFontSize * 0.7,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            if (widget.additionalInfo.isNotEmpty) ...[
              SizedBox(height: 12 * (secondaryFontSize / 40)),
              Text(
                widget.additionalInfo,
                style: AppTextStyles.bustOverlay().copyWith(
                  fontSize: tertiaryFontSize,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        );

      case GameOverlayType.killerTurnChange:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "It's ${widget.nextPlayerName}'s turn!",
              style: TextStyle(
                color: Colors.white,
                fontSize: secondaryFontSize,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            if (widget.additionalInfo.isNotEmpty) ...[
              SizedBox(height: 8 * (secondaryFontSize / 40)),
              Text(
                widget.additionalInfo,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tertiaryFontSize,
                  fontWeight: FontWeight.normal,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

      case GameOverlayType.gameWon:
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🎉 ${widget.playerName} WINS! 🎉',
              style: TextStyle(
                color: Colors.white,
                fontSize: primaryFontSize * 0.8,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                    offset: Offset(3, 3),
                    blurRadius: 6,
                    color: Colors.black54,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.additionalInfo.isNotEmpty) ...[
              SizedBox(height: 12 * (secondaryFontSize / 40)),
              Text(
                widget.additionalInfo,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tertiaryFontSize,
                  fontWeight: FontWeight.normal,
                  shadows: const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black54,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );

      case GameOverlayType.gameOver:
        return Text(
          widget.additionalInfo.isNotEmpty ? widget.additionalInfo : 'Game Over',
          style: AppTextStyles.bustOverlay().copyWith(
            fontSize: primaryFontSize * 0.8,
          ),
        );
    }
  }
}
