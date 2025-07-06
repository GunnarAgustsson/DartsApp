import 'package:flutter_test/flutter_test.dart';
import 'package:dars_scoring_app/models/killer_player.dart';
import 'package:dars_scoring_app/utils/killer_game_utils.dart';
import 'package:dars_scoring_app/models/killer_game_history.dart';
import 'package:dars_scoring_app/services/killer_game_history_service.dart';
import 'package:flutter/material.dart';

void main() {
  group('Killer Game Tests', () {
    group('KillerPlayer Model Tests', () {
      test('Player starts with correct initial state', () {
        const player = KillerPlayer(
          name: 'Test Player',
          territory: [20, 1, 18],
          health: 0,
          isKiller: false,
          hitCount: 0,
        );

        expect(player.name, equals('Test Player'));
        expect(player.territory, equals([20, 1, 18]));
        expect(player.health, equals(0));
        expect(player.isKiller, isFalse);
        expect(player.hitCount, equals(0));
        expect(player.isEliminated, isFalse); // health >= 0
      });

      test('Player becomes killer at 3+ health', () {
        const player = KillerPlayer(
          name: 'Test Player',
          territory: [20, 1, 18],
          health: 3,
          isKiller: true,
          hitCount: 3,
        );

        expect(player.isKiller, isTrue);
        expect(player.isEliminated, isFalse);
      });

      test('Player is eliminated when health goes negative', () {
        const player = KillerPlayer(
          name: 'Test Player',
          territory: [20, 1, 18],
          health: -1,
          isKiller: false,
          hitCount: 0,
        );

        expect(player.isEliminated, isTrue);
        expect(player.isKiller, isFalse);
      });

      test('Player copyWith works correctly', () {
        const player = KillerPlayer(
          name: 'Test Player',
          territory: [20, 1, 18],
          health: 0,
          isKiller: false,
          hitCount: 0,
        );

        final updatedPlayer = player.copyWith(health: 3, isKiller: true, hitCount: 3);

        expect(updatedPlayer.name, equals('Test Player'));
        expect(updatedPlayer.territory, equals([20, 1, 18]));
        expect(updatedPlayer.health, equals(3));
        expect(updatedPlayer.isKiller, isTrue);
        expect(updatedPlayer.hitCount, equals(3));
      });

      test('Player JSON serialization works correctly', () {
        const player = KillerPlayer(
          name: 'Test Player',
          territory: [20, 1, 18],
          health: 2,
          isKiller: false,
          hitCount: 2,
        );

        final json = player.toJson();
        final deserializedPlayer = KillerPlayer.fromJson(json);

        expect(deserializedPlayer.name, equals(player.name));
        expect(deserializedPlayer.territory, equals(player.territory));
        expect(deserializedPlayer.health, equals(player.health));
        expect(deserializedPlayer.isKiller, equals(player.isKiller));
        expect(deserializedPlayer.hitCount, equals(player.hitCount));
      });
    });

    group('KillerGameUtils Tests', () {
      test('Random territories generation works correctly', () {
        for (int playerCount = 2; playerCount <= 6; playerCount++) {
          final territories = KillerGameUtils.getRandomTerritories(playerCount);
          
          expect(territories.length, equals(playerCount));
          
          // Check that each territory has 3 numbers
          for (final territory in territories) {
            expect(territory.length, equals(3));
          }
          
          // Check that territories don't overlap
          final allNumbers = <int>{};
          for (final territory in territories) {
            for (final number in territory) {
              expect(allNumbers.contains(number), isFalse, 
                  reason: 'Territory number $number appears in multiple territories');
              allNumbers.add(number);
            }
          }
        }
      });

      test('Invalid player count throws error', () {
        expect(() => KillerGameUtils.getRandomTerritories(1), throwsArgumentError);
        expect(() => KillerGameUtils.getRandomTerritories(7), throwsArgumentError);
      });

      test('Dart score parsing works correctly', () {
        // Test single hits
        final single20 = KillerGameUtils.parseDartScore('20');
        expect(single20!.number, equals(20));
        expect(single20.multiplier, equals(1));
        expect(single20.isBull, isFalse);

        // Test double hits
        final double15 = KillerGameUtils.parseDartScore('D15');
        expect(double15!.number, equals(15));
        expect(double15.multiplier, equals(2));
        expect(double15.isBull, isFalse);

        // Test triple hits
        final triple10 = KillerGameUtils.parseDartScore('T10');
        expect(triple10!.number, equals(10));
        expect(triple10.multiplier, equals(3));
        expect(triple10.isBull, isFalse);

        // Test bull
        final bull = KillerGameUtils.parseDartScore('BULL');
        expect(bull!.number, equals(50));
        expect(bull.multiplier, equals(1));
        expect(bull.isBull, isTrue);

        // Test outer bull
        final outerBull = KillerGameUtils.parseDartScore('25');
        expect(outerBull!.number, equals(25));
        expect(outerBull.multiplier, equals(1));
        expect(outerBull.isBull, isFalse);

        // Test invalid input
        expect(KillerGameUtils.parseDartScore('invalid'), isNull);
        expect(KillerGameUtils.parseDartScore('T21'), isNull);
        expect(KillerGameUtils.parseDartScore('D0'), isNull);
      });

      test('Player color retrieval works correctly', () {
        for (int i = 0; i < 6; i++) {
          final color = KillerGameUtils.getPlayerColor(i);
          expect(color, isA<Color>());
        }
        
        // Test out of range returns default color
        final defaultColor = KillerGameUtils.getPlayerColor(-1);
        expect(defaultColor, equals(KillerGameUtils.playerColors[0]));
        
        final overflowColor = KillerGameUtils.getPlayerColor(10);
        expect(overflowColor, equals(KillerGameUtils.playerColors[0]));
      });

      test('Territory string conversion works correctly', () {
        final territory = [20, 1, 18];
        final stringSet = KillerGameUtils.territoryToStringSet(territory);
        
        expect(stringSet, equals({'20', '1', '18'}));
      });

      test('Hit affects territory detection works correctly', () {
        final territory = [20, 1, 18];
        
        // Test hit that affects territory
        const hit20 = DartHit(number: 20, multiplier: 1, isBull: false);
        expect(KillerGameUtils.hitAffectsTerritory(hit20, territory), isTrue);
        
        // Test hit that doesn't affect territory
        const hit5 = DartHit(number: 5, multiplier: 1, isBull: false);
        expect(KillerGameUtils.hitAffectsTerritory(hit5, territory), isFalse);
        
        // Test bull doesn't affect territory
        const bull = DartHit(number: 50, multiplier: 1, isBull: true);
        expect(KillerGameUtils.hitAffectsTerritory(bull, territory), isFalse);
      });

      test('Hit count calculation works correctly', () {
        const single = DartHit(number: 20, multiplier: 1, isBull: false);
        expect(KillerGameUtils.calculateHitCount(single), equals(1));
        
        const double = DartHit(number: 20, multiplier: 2, isBull: false);
        expect(KillerGameUtils.calculateHitCount(double), equals(2));
        
        const triple = DartHit(number: 20, multiplier: 3, isBull: false);
        expect(KillerGameUtils.calculateHitCount(triple), equals(3));
      });

      test('Player count validation works correctly', () {
        expect(KillerGameUtils.isValidPlayerCount(2), isTrue);
        expect(KillerGameUtils.isValidPlayerCount(3), isTrue);
        expect(KillerGameUtils.isValidPlayerCount(6), isTrue);
        expect(KillerGameUtils.isValidPlayerCount(1), isFalse);
        expect(KillerGameUtils.isValidPlayerCount(7), isFalse);
      });
    });

    group('KillerGameHistory Tests', () {
      test('KillerGameHistory creation from game data works correctly', () {
        final players = [
          const KillerPlayer(name: 'Player1', territory: [20, 1, 18], health: 3, isKiller: true, hitCount: 3),
          const KillerPlayer(name: 'Player2', territory: [4, 13, 6], health: -1, isKiller: false, hitCount: 2),
        ];
        
        final gameStartTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final history = KillerGameHistory.fromGameData(
          gameStartTime: gameStartTime,
          players: players,
          winner: 'Player1',
          totalDartsThrown: 25,
        );

        expect(history.playerNames, equals(['Player1', 'Player2']));
        expect(history.winner, equals('Player1'));
        expect(history.totalDartsThrown, equals(25));
        expect(history.gameStartTime, equals(gameStartTime));
        expect(history.playerTerritories['Player1'], equals([20, 1, 18]));
        expect(history.playerTerritories['Player2'], equals([4, 13, 6]));
        expect(history.finalPlayerHealth['Player1'], equals(3));
        expect(history.finalPlayerHealth['Player2'], equals(-1));
      });

      test('KillerGameHistory JSON serialization works correctly', () {
        final gameStartTime = DateTime.now().subtract(const Duration(minutes: 10));
        final gameEndTime = DateTime.now();
        
        final history = KillerGameHistory(
          id: 'test_game_123',
          gameStartTime: gameStartTime,
          gameEndTime: gameEndTime,
          playerNames: ['Player1', 'Player2'],
          winner: 'Player1',
          totalDartsThrown: 25,
          playerTerritories: {
            'Player1': [20, 1, 18],
            'Player2': [4, 13, 6],
          },
          finalPlayerHealth: {
            'Player1': 3,
            'Player2': -1,
          },
        );

        final json = history.toJson();
        final deserializedHistory = KillerGameHistory.fromJson(json);

        expect(deserializedHistory.id, equals(history.id));
        expect(deserializedHistory.playerNames, equals(history.playerNames));
        expect(deserializedHistory.winner, equals(history.winner));
        expect(deserializedHistory.totalDartsThrown, equals(history.totalDartsThrown));
        expect(deserializedHistory.playerTerritories, equals(history.playerTerritories));
        expect(deserializedHistory.finalPlayerHealth, equals(history.finalPlayerHealth));
        expect(deserializedHistory.gameStartTime.millisecondsSinceEpoch, 
               equals(history.gameStartTime.millisecondsSinceEpoch));
        expect(deserializedHistory.gameEndTime.millisecondsSinceEpoch, 
               equals(history.gameEndTime.millisecondsSinceEpoch));
      });
    });

    group('KillerGameStats Tests', () {
      test('Empty stats work correctly', () {
        final emptyStats = KillerGameStats.empty();
        
        expect(emptyStats.totalGames, equals(0));
        expect(emptyStats.totalDartsThrown, equals(0));
        expect(emptyStats.averageDartsPerGame, equals(0.0));
        expect(emptyStats.averageGameDuration, equals(Duration.zero));
        expect(emptyStats.mostSuccessfulPlayer, isNull);
        expect(emptyStats.mostWins, equals(0));
      });
    });

    group('Killer Player Statuses', () {
      test('Killer status progression works correctly', () {
        // Health 0-2: Building
        var player = const KillerPlayer(name: 'Test', territory: [20, 1, 18], health: 0, isKiller: false, hitCount: 0);
        expect(player.isEliminated, isFalse);
        expect(player.isKiller, isFalse);
        
        player = player.copyWith(health: 1, hitCount: 1);
        expect(player.isEliminated, isFalse);
        expect(player.isKiller, isFalse);
        
        player = player.copyWith(health: 2, hitCount: 2);
        expect(player.isEliminated, isFalse);
        expect(player.isKiller, isFalse);
        
        // Health 3+: Killer
        player = player.copyWith(health: 3, isKiller: true, hitCount: 3);
        expect(player.isEliminated, isFalse);
        expect(player.isKiller, isTrue);
        
        // Health negative: Eliminated
        player = player.copyWith(health: -1, isKiller: false);
        expect(player.isEliminated, isTrue);
        expect(player.isKiller, isFalse);
      });
    });
  });
}
