import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/index.dart';
import '../data/possible_finishes.dart';
import 'traditional_game_screen.dart';

class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});

  Future<List<String>> _getPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('players') ?? [];
  }

  Future<List<String>?> _showPlayerSelectionDialog(BuildContext context) async {
    final players = await _getPlayers();
    final selected = <String>[]; // use List to keep insertion order

    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Select Players (max 8)'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isSelected = selected.contains(player);
                  final order = isSelected ? selected.indexOf(player) + 1 : null;

                  return ListTile(
                    leading: isSelected
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            child: Text(
                              '$order',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : const SizedBox(width: 24), // reserve space so things don’t shift
                    title: Text(player),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true && selected.length < 8) {
                            selected.add(player);
                          } else {
                            selected.remove(player);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selected.isNotEmpty
                    ? () => Navigator.of(context).pop(selected.toList())
                    : null,
                child: const Text('Start Game'),
              ),
            ],
          ),
        );
      },
    );
  }  Future<CheckoutRule?> _showCheckoutRuleDialog(BuildContext context) async {
    CheckoutRule selectedRule = CheckoutRule.doubleOut; // Default
    
    return showDialog<CheckoutRule>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Select Checkout Rule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<CheckoutRule>(
                  title: const Text('Double Out'),
                  subtitle: const Text('Must finish on a double (including bull)'),
                  value: CheckoutRule.doubleOut,
                  groupValue: selectedRule,
                  onChanged: (value) {
                    setState(() => selectedRule = value!);
                  },
                ),
                RadioListTile<CheckoutRule>(
                  title: const Text('Master Out'),
                  subtitle: const Text('Must finish on a double or triple'),
                  value: CheckoutRule.extendedOut,
                  groupValue: selectedRule,
                  onChanged: (value) {
                    setState(() => selectedRule = value!);
                  },
                ),
                RadioListTile<CheckoutRule>(
                  title: const Text('Straight Out'),
                  subtitle: const Text('Any segment, exact score'),
                  value: CheckoutRule.exactOut,
                  groupValue: selectedRule,
                  onChanged: (value) {
                    setState(() => selectedRule = value!);
                  },
                ),
                RadioListTile<CheckoutRule>(
                  title: const Text('Open Out'),
                  subtitle: const Text('Any segment, can exceed score'),
                  value: CheckoutRule.openFinish,
                  groupValue: selectedRule,
                  onChanged: (value) {
                    setState(() => selectedRule = value!);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(selectedRule),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onGameModeSelected(BuildContext context, int startingScore) async {
    // First select the checkout rule
    final checkoutRule = await _showCheckoutRuleDialog(context);
    if (checkoutRule == null) return; // User cancelled
    
    // Then select the players
    final selectedPlayers = await _showPlayerSelectionDialog(context);
    if (selectedPlayers != null && selectedPlayers.isNotEmpty) {
      // Save the selected checkout rule for future reference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('checkoutRule', checkoutRule.index);
        Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            startingScore: startingScore,
            players: selectedPlayers,
            checkoutRule: checkoutRule,
          ),
        ),
      );
    }
  }
  /// Builds a game mode button with consistent styling
  Widget _buildGameModeButton({
    required BuildContext context,
    required String label,
    required int startingScore,
    bool isSecondary = false,
  }) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    
    // Calculate responsive button size
    final buttonWidth = size.width * (isTablet ? 0.4 : 0.7);
    
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: AppDimensions.marginM,
        horizontal: AppDimensions.marginL,
      ),
      elevation: AppDimensions.elevationM,
      child: InkWell(
        onTap: () => _onGameModeSelected(context, startingScore),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: Container(
          width: buttonWidth,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            gradient: LinearGradient(
              colors: isSecondary ? 
                [theme.colorScheme.secondary.withOpacity(0.8), theme.colorScheme.secondary] : 
                [theme.colorScheme.primary.withOpacity(0.8), theme.colorScheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: isTablet 
                  ? theme.textTheme.headlineMedium?.copyWith(color: Colors.white)
                  : theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.marginS),
              Text(
                'Starting Score: $startingScore',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isLandscape = size.width > size.height;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Game Mode'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
          ),
          child: isLandscape && size.width > 800
              ? _buildLandscapeLayout(context)
              : _buildPortraitLayout(context),
        ),
      ),
    );
  }
  
  /// Builds the portrait layout
  Widget _buildPortraitLayout(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: AppDimensions.marginL),
            Text(
              'Choose Game Mode',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.marginXL),
            _buildGameModeButton(
              context: context,
              label: '501',
              startingScore: 501,
            ),
            _buildGameModeButton(
              context: context,
              label: '301',
              startingScore: 301,
              isSecondary: true,
            ),
            // Could add more game modes here
          ],
        ),
      ),
    );
  }
  
  /// Builds the landscape layout
  Widget _buildLandscapeLayout(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildGameModeButton(
              context: context,
              label: '501',
              startingScore: 501,
            ),
          ),
          Expanded(
            child: _buildGameModeButton(
              context: context,
              label: '301',
              startingScore: 301,
              isSecondary: true,
            ),
          ),
        ],
      ),
    );
  }
}