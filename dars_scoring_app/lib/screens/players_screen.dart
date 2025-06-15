import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/screens/player_info_screen.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert'; 
import 'package:dars_scoring_app/theme/app_dimensions.dart';

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
        final theme = Theme.of(context);
        
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              'Create New Player',
              style: theme.textTheme.titleLarge,
            ),
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
                child: Text('Cancel', style: theme.textTheme.labelMedium),
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
                child: Text('Save', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white)),
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
        SnackBar(
          content: const Text('No completed games or players to export.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // 3. Create an Excel workbook and sheet
    final excel = Excel.createExcel();
    const String sheetName = 'Player History';
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
        SnackBar(
          content: const Text('Failed to generate Excel file.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isLandscape = size.width > size.height;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Players',
          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.file_download,
              color: theme.colorScheme.onPrimary,
            ),
            tooltip: 'Export All Players History',
            onPressed: _exportPlayersHistoryToExcel,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
            vertical: AppDimensions.paddingM,
          ),
          child: Column(
            children: [
              // Empty state message when no players exist
              if (players.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: isTablet ? 80 : 64,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: AppDimensions.marginM),
                        Text(
                          'No Players Yet',
                          style: isTablet
                              ? theme.textTheme.headlineMedium
                              : theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppDimensions.marginS),
                        Text(
                          'Add players to start tracking scores',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Players list
              if (players.isNotEmpty)
                Expanded(
                  child: isLandscape && isTablet
                      ? _buildGridView(theme, isTablet)
                      : _buildListView(theme, isTablet),
                ),
                
              // Add player button
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? AppDimensions.paddingM : AppDimensions.paddingS,
                  horizontal: isTablet ? AppDimensions.paddingL : AppDimensions.paddingM,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: isTablet ? 60.0 : 48.0,
                  child: ElevatedButton.icon(
                    onPressed: _showAddPlayerDialog,
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Create New Player',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildListView(ThemeData theme, bool isTablet) {
    return ListView.builder(      itemCount: players.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: AppDimensions.elevationS,
          margin: const EdgeInsets.symmetric(
            vertical: AppDimensions.marginXS,
            horizontal: AppDimensions.marginXS,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: isTablet ? AppDimensions.paddingS : 0,
            ),
            title: Text(
              players[index],
              style: isTablet
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.titleSmall,
            ),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                players[index].isNotEmpty ? players[index][0].toUpperCase() : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.delete, 
                color: theme.colorScheme.error,
                size: isTablet ? 28 : 24,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Delete Player',
                      style: theme.textTheme.titleLarge,
                    ),
                    content: Text(
                      'Are you sure you want to delete "${players[index]}"?',
                      style: theme.textTheme.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('No', style: theme.textTheme.labelMedium),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          setState(() {
                            players.removeAt(index);
                          });
                          await _savePlayers();
                        },
                        child: Text('Yes', style: theme.textTheme.labelMedium),
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
          ),
        );
      },
    );
  }
  
  Widget _buildGridView(ThemeData theme, bool isTablet) {
    return GridView.builder(      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: AppDimensions.marginM,
        mainAxisSpacing: AppDimensions.marginM,
      ),      itemCount: players.length,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemBuilder: (context, index) {
        return Card(
          elevation: AppDimensions.elevationS,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerInfoScreen(playerName: players[index]),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      players[index].isNotEmpty ? players[index][0].toUpperCase() : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),                  ),
                  const SizedBox(width: AppDimensions.marginS),
                  Expanded(
                    child: Text(
                      players[index],
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
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
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
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
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}