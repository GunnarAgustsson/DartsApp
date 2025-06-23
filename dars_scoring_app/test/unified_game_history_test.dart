import 'package:flutter_test/flutter_test.dart';
import 'package:dars_scoring_app/models/unified_game_history.dart';

void main() {  group('UnifiedGameHistory JSON Detection Tests', () {
    test('should correctly identify cricket game from JSON', () {
      final cricketJson = <String, dynamic>{
        'id': 'test-cricket-id',
        'players': ['Player1', 'Player2'],
        'gameMode': 'Cricket', // String 'Cricket'
        'createdAt': DateTime.now().toIso8601String(),
        'modifiedAt': DateTime.now().toIso8601String(),
        'playerStates': <String, dynamic>{},
        'throws': <dynamic>[],
      };
      
      final game = UnifiedGameHistory.fromJson(cricketJson);
      
      expect(game.isCricket, true);
      expect(game.gameMode, 'Cricket');
      expect(game.gameTag, 'Cricket');
    });
    
    test('should correctly identify traditional game from JSON', () {
      final traditionalJson = <String, dynamic>{
        'id': 'test-traditional-id',
        'players': ['Player1', 'Player2'],
        'gameMode': 501, // Integer 501
        'createdAt': DateTime.now().toIso8601String(),
        'modifiedAt': DateTime.now().toIso8601String(),
        'throws': <dynamic>[],
      };
      
      final game = UnifiedGameHistory.fromJson(traditionalJson);
      
      expect(game.isCricket, false);
      expect(game.gameMode, '501');
      expect(game.gameTag, 'Traditional 501');
    });
  });
}
