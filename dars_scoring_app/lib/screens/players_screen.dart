import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/screens/player_info_screen.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert'; 

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

  Future<void> _exportPlayersHistoryToExcel() async {
    // 1. Load persisted games and players
    final prefs = await SharedPreferences.getInstance();
    final rawGames = prefs.getStringList('games_history') ?? [];
    final playersList = prefs.getStringList('players') ?? [];

    // 2. Decode JSON and filter only completed games
    final completedGames = rawGames
        .map((g) => jsonDecode(g) as Map<String, dynamic>)
        .where((game) => game['completedAt'] != null)
        .toList();

    if (completedGames.isEmpty || playersList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed games or players to export.')),
      );
      return;
    }

    // 3. Create an Excel workbook and sheet
    final excel = Excel.createExcel();
    final String sheetName = 'Player History';
    final Sheet sheet = excel[sheetName];

    // 4. Append header row
    sheet.appendRow([
      TextCellValue('Player'),
      TextCellValue('Game Mode'),
      TextCellValue('Date'),
      TextCellValue('Winner'),
      TextCellValue('Throws (player,value,mult,resultScore,bust)'),
    ]);

    // 5. Populate rows
    for (final player in playersList) {
      for (final game in completedGames) {
        final playersInGame = (game['players'] as List).cast<String>();
        if (!playersInGame.contains(player)) continue;

        final throws = (game['throws'] as List)
            .where((t) => t['player'] == player)
            .map((t) =>
                '${t['player']},${t['value']},${t['multiplier']},${t['resultingScore']},${t['wasBust'] ?? false}')
            .join(' | ');

        sheet.appendRow([
          TextCellValue(player),
          TextCellValue(game['gameMode']?.toString() ?? ''),
          TextCellValue(game['createdAt']?.toString() ?? ''),
          TextCellValue(game['winner']?.toString() ?? ''),
          TextCellValue(throws),
        ]);
      }
    }

    // 6. Save to a temporary file
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate Excel file.')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/players_history.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // 7. Share the file
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Darts Players History Export',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export All Players History',
            onPressed: _exportPlayersHistoryToExcel,
          ),
        ],
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