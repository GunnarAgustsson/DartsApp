import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/index.dart';
import 'players_screen.dart';
import 'game_modes_screen.dart';
import '../widgets/game_history_view.dart';
import 'options_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = size.width > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('DARTS Scoring App'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).isDarkMode 
                  ? Icons.light_mode 
                  : Icons.dark_mode,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(
              isTablet ? AppDimensions.paddingL : AppDimensions.paddingM
            ),
            child: isLandscape && size.width > 800
                ? _buildLandscapeLayout(context, theme, isTablet)
                : _buildPortraitLayout(context, theme, isTablet),
          ),
        ),
      ),
    );
  }
  
  /// Builds the portrait layout
  Widget _buildPortraitLayout(BuildContext context, ThemeData theme, bool isTablet) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: isTablet ? AppDimensions.marginXL : AppDimensions.marginL),
        
        // Welcome text
        Text(
          'Welcome to DARTS Scoring!',
          style: isTablet 
              ? theme.textTheme.headlineMedium 
              : theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: isTablet ? AppDimensions.marginXL * 1.5 : AppDimensions.marginXL),
        
        // Dartboard icon with container
        _buildDartboardIcon(isTablet),
        
        SizedBox(height: isTablet ? AppDimensions.marginXL * 1.5 : AppDimensions.marginXL),
        
        // Menu buttons
        _buildMenuButtons(context, theme, isTablet),
      ],
    );
  }    /// Builds the dartboard icon with a circular container
  Widget _buildDartboardIcon(bool isTablet) {
    final double iconSize = isTablet 
        ? AppDimensions.dartboardIconSize * 1.5 
        : AppDimensions.dartboardIconSize;
        
    return Stack(
      alignment: Alignment.center,
      children: [
        // Black circle background
        Container(
          width: iconSize,
          height: iconSize,
          decoration: const BoxDecoration(
            color: AppColors.dartBoardBlack,
            shape: BoxShape.circle,
          ),
        ),
        
        // Dartboard image
        Container(
          width: iconSize + 20,
          height: iconSize + 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/icons/dartboard.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
  
  /// Builds the landscape layout
  Widget _buildLandscapeLayout(BuildContext context, ThemeData theme, bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: _buildDartboardIcon(isTablet),
        ),
        const SizedBox(width: AppDimensions.marginL),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to DARTS Scoring!',
                style: isTablet 
                    ? theme.textTheme.headlineMedium 
                    : theme.textTheme.headlineSmall,
              ),
              SizedBox(height: isTablet ? AppDimensions.marginL : AppDimensions.marginM),
              _buildMenuButtons(context, theme, isTablet),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Group all menu buttons into a column
  Widget _buildMenuButtons(BuildContext context, ThemeData theme, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMenuButton(
          context: context,
          label: 'New Game',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GameModeScreen()),
          ),
          icon: Icons.play_arrow,
        ),
        
        SizedBox(height: isTablet ? AppDimensions.marginL : AppDimensions.marginM),
        
        _buildMenuButton(
          context: context,
          label: 'History',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Game History'),
                ),
                body: const GameHistoryView(
                  showRefreshButton: true,
                  allowDelete: true,
                ),
              ),
            ),
          ),
          icon: Icons.history,
        ),
        
        SizedBox(height: isTablet ? AppDimensions.marginL : AppDimensions.marginM),
        
        _buildMenuButton(
          context: context,
          label: 'Players',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PlayersScreen()),
          ),
          icon: Icons.people,
        ),
        
        SizedBox(height: isTablet ? AppDimensions.marginL : AppDimensions.marginM),
        
        _buildMenuButton(
          context: context,
          label: 'Options',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OptionsScreen(),
            ),
          ),
          icon: Icons.settings,
        ),
      ],
    );
  }
    /// Builds a menu button with consistent styling
  Widget _buildMenuButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isTablet = width > 600;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    
    // Calculate a sensible button width based on screen width and orientation
    final double buttonWidth;
    if (isLandscape && width > 800) {
      buttonWidth = double.infinity;  // Full width in landscape
    } else {
      buttonWidth = width * (isTablet ? 0.6 : 0.8);
    }
    
    return SizedBox(
      width: buttonWidth,
      height: isTablet ? AppDimensions.buttonHeightL : AppDimensions.buttonHeightM,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
            vertical: isTablet ? AppDimensions.paddingM : AppDimensions.paddingS,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isTablet ? AppDimensions.iconL : AppDimensions.iconM),
            SizedBox(width: isTablet ? AppDimensions.marginM : AppDimensions.marginS),
            Text(
              label,
              style: (isTablet ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}