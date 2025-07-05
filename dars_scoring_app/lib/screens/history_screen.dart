import 'package:flutter/material.dart';
import '../widgets/game_history_view.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
      ),
      body: const GameHistoryView(
        showRefreshButton: true,
        allowDelete: true,
      ),
    );
  }
}