import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_scoring_app/models/game_history.dart';
import 'package:dars_scoring_app/data/possible_finishes.dart';


/// Repository for persisting game history and user preferences.
class HistoryRepository {
  static const _gamesKey = 'games_history';
  static const _checkoutRuleKey = 'checkoutRule';

  /// Loads the saved [CheckoutRule], defaulting to openFinish.
  Future<CheckoutRule> getCheckoutRule() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_checkoutRuleKey) ?? 0;
    return CheckoutRule.values[idx];
  }

  /// Saves the user's preferred [CheckoutRule].
  Future<void> saveCheckoutRule(CheckoutRule rule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_checkoutRuleKey, rule.index);
  }

  /// Persists the [currentGame] history list in SharedPreferences.
  Future<void> saveGameHistory(GameHistory currentGame) async {
    final prefs = await SharedPreferences.getInstance();
    final games = prefs.getStringList(_gamesKey) ?? [];
    final json = jsonEncode(currentGame.toJson());
    final idx = games.indexWhere((g) {
      return jsonDecode(g)['id'] == currentGame.id;
    });
    if (idx < 0) {
      games.add(json);
    } else {
      games[idx] = json;
    }
    await prefs.setStringList(_gamesKey, games);
  }

  /// Loads all saved [GameHistory] entries.
  Future<List<GameHistory>> loadAllGames() async {
    final prefs = await SharedPreferences.getInstance();
    final games = prefs.getStringList(_gamesKey) ?? [];
    return games.map((g) {
      final map = jsonDecode(g) as Map<String, dynamic>;
      return GameHistory.fromJson(map);
    }).toList();
  }
}
