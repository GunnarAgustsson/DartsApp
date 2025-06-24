import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/index.dart';
import '../models/app_enums.dart';
import '../models/game_details.dart';
import '../data/possible_finishes.dart';
import 'traditional_game_screen.dart';
import 'cricket_game_screen.dart';

class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});

  Future<List<String>> _getPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('players') ?? [];
  }

  /// Show dialog to select traditional game variant (301, 501, 1001)
  Future<PlayerSelectionDetails?> _showTraditionalGameDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final players = await _getPlayers();
    final selectedPlayersList = <String>[];

    bool randomOrder = prefs.getBool('randomOrder') ?? false;
    TraditionalVariant selectedVariant = TraditionalVariant.game501;
    CheckoutRule selectedRule = CheckoutRule.values[prefs.getInt('checkoutRule') ?? CheckoutRule.doubleOut.index];

    return showDialog<PlayerSelectionDetails>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Setup Traditional Game'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Game Variant:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TraditionalVariant>(
                      value: selectedVariant,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      isExpanded: true,
                      items: TraditionalVariant.values.map((TraditionalVariant variant) {
                        return DropdownMenuItem<TraditionalVariant>(
                          value: variant,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(variant.title, style: const TextStyle(fontSize: 16)),
                              Text(
                                variant.description,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (TraditionalVariant? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            selectedVariant = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Select Checkout Rule:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CheckoutRule>(
                      value: selectedRule,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      isExpanded: true,
                      items: CheckoutRule.values.map((CheckoutRule rule) {
                        return DropdownMenuItem<CheckoutRule>(
                          value: rule,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_getCheckoutRuleTitle(rule), style: const TextStyle(fontSize: 16)),
                              Text(
                                _getCheckoutRuleSubtitle(rule),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (CheckoutRule? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            selectedRule = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
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
                      physics: const NeverScrollableScrollPhysics(),
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
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey,
                                  child: SizedBox(),
                                ),
                          title: Text(player),
                          onTap: () {
                            setStateDialog(() {
                              if (isSelected) {
                                selectedPlayersList.remove(player);
                              } else if (selectedPlayersList.length < 8) {
                                selectedPlayersList.add(player);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedPlayersList.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(PlayerSelectionDetails(
                        players: selectedPlayersList.toList(), 
                        checkoutRule: selectedRule, 
                        startingScore: selectedVariant.startingScore, 
                        randomOrder: randomOrder
                      )),
                child: const Text('Start Game'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show dialog to select cricket game variant
  Future<CricketGameDetails?> _showCricketGameDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final players = await _getPlayers();
    final selectedPlayersList = <String>[];

    bool randomOrder = prefs.getBool('randomOrder') ?? false;
    CricketVariant selectedVariant = CricketVariant.standard;

    return showDialog<CricketGameDetails>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Setup Cricket Game'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Cricket Variant:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CricketVariant>(
                      value: selectedVariant,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      isExpanded: true,
                      items: CricketVariant.values.map((CricketVariant variant) {
                        return DropdownMenuItem<CricketVariant>(
                          value: variant,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(variant.title, style: const TextStyle(fontSize: 16)),
                              Text(
                                variant.description,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (CricketVariant? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            selectedVariant = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
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
                      physics: const NeverScrollableScrollPhysics(),
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
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.grey,
                                  child: SizedBox(),
                                ),
                          title: Text(player),
                          onTap: () {
                            setStateDialog(() {
                              if (isSelected) {
                                selectedPlayersList.remove(player);
                              } else if (selectedPlayersList.length < 8) {
                                selectedPlayersList.add(player);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedPlayersList.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(CricketGameDetails(
                        players: selectedPlayersList.toList(), 
                        variant: selectedVariant, 
                        randomOrder: randomOrder
                      )),
                child: const Text('Start Game'),
              ),
            ],
          ),
        );
      },
    );
  }

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

  void _onTraditionalGameSelected(BuildContext context) async {
    final selectionDetails = await _showTraditionalGameDialog(context);

    if (selectionDetails != null && selectionDetails.players.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lastSelectedPlayers', selectionDetails.players);
      await prefs.setInt('checkoutRule', selectionDetails.checkoutRule.index);
      await prefs.setBool('randomOrder', selectionDetails.randomOrder);

      List<String> finalPlayerOrder = List.from(selectionDetails.players);
      if (selectionDetails.randomOrder) {
        finalPlayerOrder.shuffle();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            startingScore: selectionDetails.startingScore,
            players: finalPlayerOrder,
            checkoutRule: selectionDetails.checkoutRule,
            randomOrder: selectionDetails.randomOrder,
          ),
        ),
      );
    }
  }

  void _onCricketGameSelected(BuildContext context) async {
    final selectionDetails = await _showCricketGameDialog(context);

    if (selectionDetails != null && selectionDetails.players.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lastSelectedPlayers', selectionDetails.players);
      await prefs.setBool('randomOrder', selectionDetails.randomOrder);

      List<String> finalPlayerOrder = List.from(selectionDetails.players);
      if (selectionDetails.randomOrder) {
        finalPlayerOrder.shuffle();
      }      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CricketGameScreen(
            players: finalPlayerOrder,
            randomOrder: selectionDetails.randomOrder,
            variant: selectionDetails.variant,
          ),
        ),
      );
    }
  }

  Widget _buildGameModeCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Container(
      width: isTablet ? 300 : double.infinity,
      margin: EdgeInsets.symmetric(
        vertical: AppDimensions.marginM,
        horizontal: isTablet ? AppDimensions.marginL : AppDimensions.marginM,
      ),
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isTablet ? 64 : 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppDimensions.marginM),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.marginS),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
          child: Center(
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
                  
                  if (isLandscape && size.width > 800)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGameModeCard(
                          context: context,
                          title: 'Traditional',
                          description: 'Choose from 301, 501, or 1001 variants',
                          icon: Icons.track_changes,
                          onTap: () => _onTraditionalGameSelected(context),
                        ),
                        _buildGameModeCard(
                          context: context,
                          title: 'Cricket',
                          description: 'Standard, Race, or Quick Cricket variants',
                          icon: Icons.sports_baseball,
                          onTap: () => _onCricketGameSelected(context),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildGameModeCard(
                          context: context,
                          title: 'Traditional',
                          description: 'Choose from 301, 501, or 1001 variants',
                          icon: Icons.track_changes,
                          onTap: () => _onTraditionalGameSelected(context),
                        ),
                        _buildGameModeCard(
                          context: context,
                          title: 'Cricket',
                          description: 'Standard, Race, or Quick Cricket variants',
                          icon: Icons.sports_baseball,
                          onTap: () => _onCricketGameSelected(context),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: AppDimensions.marginXL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
