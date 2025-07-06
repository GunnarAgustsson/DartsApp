import 'package:flutter/material.dart';

/// Animation types for the Killer game overlay
enum KillerOverlayType {
  playerEliminated,
  playerBecomesKiller,
  turnChange,
}

/// A widget that shows animated overlays for Killer game events
class KillerOverlayAnimation extends StatefulWidget {

  const KillerOverlayAnimation({
    super.key,
    required this.overlayType,
    required this.playerName,
    required this.isVisible,
    this.onAnimationComplete,
  });
  /// The type of overlay to show
  final KillerOverlayType overlayType;
  
  /// The player name for the event
  final String playerName;
  
  /// Whether the overlay is visible
  final bool isVisible;
  
  /// Callback when animation completes
  final VoidCallback? onAnimationComplete;

  @override
  State<KillerOverlayAnimation> createState() => _KillerOverlayAnimationState();
}

class _KillerOverlayAnimationState extends State<KillerOverlayAnimation>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(KillerOverlayAnimation oldWidget) {
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
    
    // Auto-hide after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _hideAnimation();
    }
  }

  void _hideAnimation() async {
    await _fadeController.reverse();
    await _scaleController.reverse();
    
    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  Color _getBackgroundColor() {
    switch (widget.overlayType) {
      case KillerOverlayType.playerEliminated:
        return Colors.red.withOpacity(0.9);
      case KillerOverlayType.playerBecomesKiller:
        return Colors.amber.withOpacity(0.9);
      case KillerOverlayType.turnChange:
        return Colors.blue.withOpacity(0.9);
    }
  }

  IconData _getIcon() {
    switch (widget.overlayType) {
      case KillerOverlayType.playerEliminated:
        return Icons.close;
      case KillerOverlayType.playerBecomesKiller:
        return Icons.star;
      case KillerOverlayType.turnChange:
        return Icons.arrow_forward;
    }
  }

  String _getTitle() {
    switch (widget.overlayType) {
      case KillerOverlayType.playerEliminated:
        return 'ELIMINATED';
      case KillerOverlayType.playerBecomesKiller:
        return 'KILLER';
      case KillerOverlayType.turnChange:
        return 'NEXT TURN';
    }
  }

  String _getSubtitle() {
    switch (widget.overlayType) {
      case KillerOverlayType.playerEliminated:
        return '${widget.playerName} is out!';
      case KillerOverlayType.playerBecomesKiller:
        return '${widget.playerName} becomes a killer!';
      case KillerOverlayType.turnChange:
        return '${widget.playerName}\'s turn';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _getBackgroundColor(),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        Icon(
                          _getIcon(),
                          size: 64,
                          color: Colors.white,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Title
                        Text(
                          _getTitle(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Subtitle
                        Text(
                          _getSubtitle(),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
