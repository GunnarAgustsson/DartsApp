import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/screens/player_info_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final List<String> players = [];

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      players.clear();
      players.addAll(prefs.getStringList('players') ?? []);
    });
  }

  Future<void> _savePlayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('players', players);
  }

  void _showAddPlayerDialog() {
    final TextEditingController controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Create New Player'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Player Name',
                errorText: errorText,
              ),
              onChanged: (_) {
                if (errorText != null) {
                  setState(() => errorText = null);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    setState(() => errorText = 'Name cannot be empty');
                  } else if (players.contains(name)) {
                    setState(() => errorText = 'Name already exists');
                  } else {
                    Navigator.of(context).pop();
                    players.add(name);
                    await _savePlayers();
                    // Refresh the list from storage
                    if (mounted) {
                      setState(() {});
                      await _loadPlayers();
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(players[index]),
                  leading: const Icon(Icons.person),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Player'),
                          content: Text('Are you sure you want to delete "${players[index]}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('No'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                setState(() {
                                  players.removeAt(index);
                                });
                                await _savePlayers();
                              },
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayerInfoScreen(playerName: players[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddPlayerDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create New Player'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}