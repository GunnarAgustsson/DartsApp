import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/index.dart';
import '../data/possible_finishes.dart';
import 'traditional_game_screen.dart';

// Add this class definition
class PlayerSelectionDetails {
  final List<String> players;
  final CheckoutRule checkoutRule;
  final bool randomOrder;

  PlayerSelectionDetails(this.players, this.checkoutRule, this.randomOrder);
}

class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});

  String _getCheckoutRuleTitle(CheckoutRule rule) {
    switch (rule) {
      case CheckoutRule.doubleOut:
        return 'Double Out';
      case CheckoutRule.extendedOut:
        return 'Master Out';
      case CheckoutRule.exactOut:
        return 'Straight Out';
      case CheckoutRule.openFinish:
        return 'Open Out';
    }
  }

  String _getCheckoutRuleSubtitle(CheckoutRule rule) {
    switch (rule) {
      case CheckoutRule.doubleOut:
        return 'Finish on a double (or bull)';
      case CheckoutRule.extendedOut:
        return 'Finish on a double or triple';
      case CheckoutRule.exactOut:
        return 'Any segment, exact score';
      case CheckoutRule.openFinish:
        return 'Any segment, can exceed score';
    }
  }

  Future<List<String>> _getPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('players') ?? [];
  }
  Future<PlayerSelectionDetails?> _showPlayerSelectionDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final players = await _getPlayers();
    final selectedPlayersList = <String>[];

    CheckoutRule selectedRule = CheckoutRule.values[prefs.getInt('checkoutRule') ?? CheckoutRule.doubleOut.index];
    String selectedRuleSubtitle = _getCheckoutRuleSubtitle(selectedRule); // Helper to get subtitle
    bool randomOrder = prefs.getBool('randomOrder') ?? false; // Get saved random order preference

    return showDialog<PlayerSelectionDetails>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Setup Game'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Checkout Rule:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<CheckoutRule>(
                      value: selectedRule,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15), // Adjust vertical padding for height
                      ),
                      isExpanded: true,
                      // itemHeight: null, // Remove itemHeight, let items size naturally or set to default
                      selectedItemBuilder: (BuildContext context) { // Custom builder for selected item display
                        return CheckoutRule.values.map<Widget>((CheckoutRule rule) {
                          return Text(_getCheckoutRuleTitle(rule)); // Display only title
                        }).toList();
                      },
                      items: CheckoutRule.values.map((CheckoutRule rule) {
                        return DropdownMenuItem<CheckoutRule>(
                          value: rule,
                          child: Column( // Keep full details for dropdown items
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_getCheckoutRuleTitle(rule), style: const TextStyle(fontSize: 16)),
                              Text(
                                _getCheckoutRuleSubtitle(rule),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (CheckoutRule? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            selectedRule = newValue;
                            selectedRuleSubtitle = _getCheckoutRuleSubtitle(newValue); // Update subtitle
                          });
                        }
                      },
                    ),
                    Padding( // Display subtitle underneath the dropdown
                      padding: const EdgeInsets.only(top: 4.0, left: 2.0),
                      child: Text(
                        selectedRuleSubtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(height: 16), // Adjusted spacing
                    
                    // Random Order Checkbox
                    CheckboxListTile(
                      title: const Text('Random Player Order', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        randomOrder 
                            ? 'Players will be shuffled randomly at game start and on play again'
                            : 'Players will follow selection order, shifting by one on play again',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      value: randomOrder,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          randomOrder = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    
                    const Text('Select Players (max 8):', style: TextStyle(fontWeight: FontWeight.bold)),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), // To prevent nested scrolling issues
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        final isSelected = selectedPlayersList.contains(player);
                        final order = isSelected ? selectedPlayersList.indexOf(player) + 1 : null;

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
                              : const SizedBox(width: 24),
                          title: Text(player),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (checked) {
                              setStateDialog(() { // Use setStateDialog
                                if (checked == true && selectedPlayersList.length < 8) {
                                  selectedPlayersList.add(player);
                                } else {
                                  selectedPlayersList.remove(player);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedPlayersList.isNotEmpty
                    ? () => Navigator.of(context).pop(PlayerSelectionDetails(selectedPlayersList.toList(), selectedRule, randomOrder))
                    : null,
                child: const Text('Start Game'),
              ),
            ],
          ),
        );
      },
    );
  }
  void _onGameModeSelected(BuildContext context, int startingScore) async {
    // Show the combined player and rule selection dialog
    final selectionDetails = await _showPlayerSelectionDialog(context);

    if (selectionDetails != null && selectionDetails.players.isNotEmpty) {
      // Save the selected checkout rule and random order preference for future reference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('checkoutRule', selectionDetails.checkoutRule.index);
      await prefs.setBool('randomOrder', selectionDetails.randomOrder);

      // Shuffle players if random order is enabled
      List<String> finalPlayerOrder = List.from(selectionDetails.players);
      if (selectionDetails.randomOrder) {
        finalPlayerOrder.shuffle();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            startingScore: startingScore,
            players: finalPlayerOrder,
            checkoutRule: selectionDetails.checkoutRule,
            randomOrder: selectionDetails.randomOrder,
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