import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/index.dart';
import '../models/app_enums.dart';
import '../models/game_details.dart';
import '../data/possible_finishes.dart';
import 'traditional_game_screen.dart';
import 'cricket_game_screen.dart';
import 'donkey_game_screen.dart';
import 'killer_game_screen.dart';

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
                          child: Text(variant.title, style: const TextStyle(fontSize: 16)),
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
                          child: Text(_getCheckoutRuleTitle(rule), style: const TextStyle(fontSize: 16)),
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
                    
                    const SizedBox(height: 16),
                    
                    // Game Description Section
                    Card(
                      elevation: 2,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Game Description:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedVariant.description,
                              style: TextStyle(
                                fontSize: 13, 
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Checkout Rule:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getCheckoutRuleSubtitle(selectedRule),
                              style: TextStyle(
                                fontSize: 13, 
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          child: Text(variant.title, style: const TextStyle(fontSize: 16)),
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
                    
                    const SizedBox(height: 16),
                    
                    // Game Description Section
                    Card(
                      elevation: 2,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Game Description:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedVariant.description,
                              style: TextStyle(
                                fontSize: 13, 
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
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
    );  }

  /// Show dialog to select donkey game variant
  Future<DonkeyGameDetails?> _showDonkeyGameDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final players = await _getPlayers();
    final selectedPlayersList = <String>[];

    bool randomOrder = prefs.getBool('randomOrder') ?? false;
    DonkeyVariant selectedVariant = DonkeyVariant.oneDart;

    return showDialog<DonkeyGameDetails>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Setup Donkey Game'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Donkey Variant:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DonkeyVariant>(
                      value: selectedVariant,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      isExpanded: true,
                      items: DonkeyVariant.values.map((DonkeyVariant variant) {
                        return DropdownMenuItem<DonkeyVariant>(
                          value: variant,
                          child: Text(variant.title, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                      onChanged: (DonkeyVariant? newValue) {
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
                    
                    const Text('Select Players (2-8 players):', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    
                    const SizedBox(height: 16),
                    
                    // Game Description Section
                    Card(
                      elevation: 2,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Game Description:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedVariant.description,
                              style: TextStyle(
                                fontSize: 13, 
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                onPressed: selectedPlayersList.length < 2
                    ? null
                    : () => Navigator.of(context).pop(DonkeyGameDetails(
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

  /// Show dialog to select killer game settings
  Future<KillerGameDetails?> _showKillerGameDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final players = await _getPlayers();
    final selectedPlayersList = <String>[];

    bool randomOrder = prefs.getBool('randomOrder') ?? false;

    return showDialog<KillerGameDetails>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Setup Killer Game'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    
                    const Text('Select Players (2-8 players):', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    
                    const SizedBox(height: 16),
                    
                    // Game Description Section
                    Card(
                      elevation: 2,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Game Description:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Elimination dart game where players compete for territories. Hit your assigned number to gain health and become a killer (3+ health). Killers can attack others by hitting their territories. Players are eliminated when their health goes below 0.',
                              style: TextStyle(
                                fontSize: 13, 
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                onPressed: selectedPlayersList.length < 2
                    ? null
                    : () => Navigator.of(context).pop(KillerGameDetails(
                        players: selectedPlayersList.toList(), 
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
        finalPlayerOrder.shuffle();      }      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CricketGameScreen(
            players: finalPlayerOrder,
            randomOrder: selectionDetails.randomOrder,
            variant: selectionDetails.variant,
          ),
        ),
      );
    }  }

  void _onDonkeyGameSelected(BuildContext context) async {
    final selectionDetails = await _showDonkeyGameDialog(context);

    if (selectionDetails != null && selectionDetails.players.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lastSelectedPlayers', selectionDetails.players);
      await prefs.setBool('randomOrder', selectionDetails.randomOrder);

      List<String> finalPlayerOrder = List.from(selectionDetails.players);
      if (selectionDetails.randomOrder) {
        finalPlayerOrder.shuffle();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DonkeyGameScreen(
            players: finalPlayerOrder,
            randomOrder: selectionDetails.randomOrder,
            variant: selectionDetails.variant,
          ),
        ),
      );
    }
  }

  void _onKillerGameSelected(BuildContext context) async {
    final selectionDetails = await _showKillerGameDialog(context);

    if (selectionDetails != null && selectionDetails.players.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lastSelectedPlayers', selectionDetails.players);
      await prefs.setBool('randomOrder', selectionDetails.randomOrder);

      List<String> finalPlayerOrder = List.from(selectionDetails.players);
      if (selectionDetails.randomOrder) {
        finalPlayerOrder.shuffle();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KillerGameScreen(
            playerNames: finalPlayerOrder,
            randomOrder: selectionDetails.randomOrder,
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
                    if (isLandscape && size.width > 1200)
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
                        _buildGameModeCard(
                          context: context,
                          title: 'Donkey',
                          description: 'HORSE-style game - beat the score or get a letter',
                          icon: Icons.psychology,
                          onTap: () => _onDonkeyGameSelected(context),
                        ),
                        _buildGameModeCard(
                          context: context,
                          title: 'Killer',
                          description: 'Elimination game - be the last player standing',
                          icon: Icons.gps_fixed,
                          onTap: () => _onKillerGameSelected(context),
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
                        _buildGameModeCard(
                          context: context,
                          title: 'Donkey',
                          description: 'HORSE-style game - beat the score or get a letter',
                          icon: Icons.psychology,
                          onTap: () => _onDonkeyGameSelected(context),
                        ),
                        _buildGameModeCard(
                          context: context,
                          title: 'Killer',
                          description: 'Elimination game - be the last player standing',
                          icon: Icons.gps_fixed,
                          onTap: () => _onKillerGameSelected(context),
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
