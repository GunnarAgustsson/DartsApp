import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utility functions for Killer darts game logic
class KillerGameUtils {
  KillerGameUtils._(); // Private constructor - utility class

  /// Dartboard numbers in clockwise order starting from top (20)
  static const List<int> dartboardNumbers = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5
  ];

  /// Predefined colors for players (distinct and visible)
  static const List<Color> playerColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF4CAF50), // Green
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF00BCD4), // Cyan
  ];

  /// Generates random territories for the given number of players
  /// Each territory consists of 3 consecutive dartboard numbers
  /// Ensures no overlap between territories using smart conflict resolution
  static List<List<int>> getRandomTerritories(int playerCount) {
    if (playerCount < 2 || playerCount > 6) {
      throw ArgumentError('Player count must be between 2 and 6');
    }

    final random = math.Random();
    final territories = <List<int>>[];
    final usedNumbers = <int>{};

    // First, try to place territories randomly without conflicts
    for (int i = 0; i < playerCount; i++) {
      List<int>? territory = _findAvailableTerritory(usedNumbers, random);
      
      if (territory != null) {
        territories.add(territory);
        usedNumbers.addAll(territory);
      } else {
        // No clean spot available, use conflict resolution
        territory = _resolveConflictAndPlace(territories, usedNumbers, random);
        territories.add(territory);
        usedNumbers.addAll(territory);
      }
    }

    return territories;
  }

  /// Finds an available 3-consecutive territory without conflicts
  static List<int>? _findAvailableTerritory(Set<int> usedNumbers, math.Random random) {
    // Create a list of all possible starting positions
    final availableStartPositions = <int>[];
    
    for (int startIndex = 0; startIndex < dartboardNumbers.length; startIndex++) {
      final territory = _getConsecutiveNumbers(startIndex, 3);
      if (!_hasOverlap(territory, usedNumbers)) {
        availableStartPositions.add(startIndex);
      }
    }
    
    if (availableStartPositions.isEmpty) {
      return null; // No clean spots available
    }
    
    // Pick a random available position
    final chosenStartIndex = availableStartPositions[random.nextInt(availableStartPositions.length)];
    return _getConsecutiveNumbers(chosenStartIndex, 3);
  }

  /// Resolves conflicts by moving existing territories to make space
  static List<int> _resolveConflictAndPlace(List<List<int>> existingTerritories, Set<int> usedNumbers, math.Random random) {
    // Find the least crowded area on the dartboard
    final conflictCounts = <int, int>{};
    
    // Count how many territories would conflict with each possible position
    for (int startIndex = 0; startIndex < dartboardNumbers.length; startIndex++) {
      final territory = _getConsecutiveNumbers(startIndex, 3);
      final conflicts = territory.where((num) => usedNumbers.contains(num)).length;
      conflictCounts[startIndex] = conflicts;
    }
    
    // Find positions with minimum conflicts
    final minConflicts = conflictCounts.values.reduce(math.min);
    final bestPositions = conflictCounts.entries
        .where((entry) => entry.value == minConflicts)
        .map((entry) => entry.key)
        .toList();
    
    // Pick a random best position
    final chosenStartIndex = bestPositions[random.nextInt(bestPositions.length)];
    final newTerritory = _getConsecutiveNumbers(chosenStartIndex, 3);
    
    // Now we need to move conflicting territories
    final conflictingNumbers = newTerritory.where((num) => usedNumbers.contains(num)).toSet();
    
    if (conflictingNumbers.isNotEmpty) {
      // Find which territories need to be moved
      final territoriesToMove = <int>[];
      for (int i = 0; i < existingTerritories.length; i++) {
        if (existingTerritories[i].any((num) => conflictingNumbers.contains(num))) {
          territoriesToMove.add(i);
        }
      }
      
      // Remove conflicting territories from used numbers
      for (final territoryIndex in territoriesToMove) {
        for (final num in existingTerritories[territoryIndex]) {
          usedNumbers.remove(num);
        }
      }
      
      // Relocate conflicting territories
      for (final territoryIndex in territoriesToMove) {
        final relocatedTerritory = _findAvailableTerritory(usedNumbers, random);
        if (relocatedTerritory != null) {
          existingTerritories[territoryIndex] = relocatedTerritory;
          usedNumbers.addAll(relocatedTerritory);
        } else {
          // If we still can't place it, use a single number fallback
          final availableSingle = _findAvailableSingleNumber(usedNumbers, random);
          existingTerritories[territoryIndex] = [availableSingle];
          usedNumbers.add(availableSingle);
        }
      }
    }
    
    return newTerritory;
  }

  /// Finds a single available number when no 3-consecutive spots are available
  static int _findAvailableSingleNumber(Set<int> usedNumbers, math.Random random) {
    final availableNumbers = dartboardNumbers.where((num) => !usedNumbers.contains(num)).toList();
    
    if (availableNumbers.isEmpty) {
      // This should never happen with 6 players max (18 numbers used, 2 free)
      // But as a fallback, pick any number
      return dartboardNumbers[random.nextInt(dartboardNumbers.length)];
    }
    
    return availableNumbers[random.nextInt(availableNumbers.length)];
  }

  /// Gets consecutive numbers from the dartboard starting at the given index
  static List<int> _getConsecutiveNumbers(int startIndex, int count) {
    final result = <int>[];
    for (int i = 0; i < count; i++) {
      final index = (startIndex + i) % dartboardNumbers.length;
      result.add(dartboardNumbers[index]);
    }
    return result;
  }

  /// Checks if a territory overlaps with already used numbers
  static bool _hasOverlap(List<int> territory, Set<int> usedNumbers) {
    return territory.any((number) => usedNumbers.contains(number));
  }

  /// Parses a dart score string and returns the hit information
  /// Examples: "20", "T15", "D5", "BULL", "25"
  /// Returns null if invalid
  static DartHit? parseDartScore(String input) {
    if (input.isEmpty) return null;
    
    final cleanInput = input.trim().toUpperCase();
    
    // Handle bull
    if (cleanInput == 'BULL' || cleanInput == '50') {
      return DartHit(number: 50, multiplier: 1, isBull: true);
    }
    
    // Handle outer bull
    if (cleanInput == '25') {
      return DartHit(number: 25, multiplier: 1, isBull: false);
    }
    
    // Handle multipliers
    if (cleanInput.startsWith('T')) {
      final numberStr = cleanInput.substring(1);
      final number = int.tryParse(numberStr);
      if (number != null && number >= 1 && number <= 20) {
        return DartHit(number: number, multiplier: 3, isBull: false);
      }
    }
    
    if (cleanInput.startsWith('D')) {
      final numberStr = cleanInput.substring(1);
      final number = int.tryParse(numberStr);
      if (number != null && number >= 1 && number <= 20) {
        return DartHit(number: number, multiplier: 2, isBull: false);
      }
    }
    
    // Handle single numbers
    final number = int.tryParse(cleanInput);
    if (number != null && number >= 1 && number <= 20) {
      return DartHit(number: number, multiplier: 1, isBull: false);
    }
    
    return null;
  }

  /// Validates if a player count is valid for Killer game
  static bool isValidPlayerCount(int count) {
    return count >= 2 && count <= 6;
  }

  /// Gets the color for a player by index
  static Color getPlayerColor(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= playerColors.length) {
      return playerColors[0]; // Default to first color
    }
    return playerColors[playerIndex];
  }

  /// Converts territory numbers to string set for dartboard highlighting
  static Set<String> territoryToStringSet(List<int> territory) {
    return territory.map((number) => number.toString()).toSet();
  }

  /// Checks if a dart hit affects a specific territory
  static bool hitAffectsTerritory(DartHit hit, List<int> territory) {
    if (hit.isBull) return false; // Bull doesn't affect territories
    return territory.contains(hit.number);
  }

  /// Calculates how many hits this dart represents (accounting for multipliers)
  static int calculateHitCount(DartHit hit) {
    return hit.multiplier;
  }
}

/// Represents a single dart hit
class DartHit {
  /// The number hit on the dartboard (1-20, 25, or 50)
  final int number;
  
  /// The multiplier (1 = single, 2 = double, 3 = triple)
  final int multiplier;
  
  /// Whether this is a bull hit (25 or 50)
  final bool isBull;

  const DartHit({
    required this.number,
    required this.multiplier,
    required this.isBull,
  });

  /// The total score for this hit
  int get score => number * multiplier;

  @override
  String toString() {
    if (isBull) {
      return number == 50 ? 'BULL' : '25';
    }
    
    switch (multiplier) {
      case 2:
        return 'D$number';
      case 3:
        return 'T$number';
      default:
        return number.toString();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DartHit &&
        other.number == number &&
        other.multiplier == multiplier &&
        other.isBull == isBull;
  }

  @override
  int get hashCode => Object.hash(number, multiplier, isBull);
}
