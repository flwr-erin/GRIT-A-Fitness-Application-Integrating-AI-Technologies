import 'package:cloud_firestore/cloud_firestore.dart';

class MuscleProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache the stats to reduce unnecessary Firestore reads
  final Map<String, Map<String, Map<String, dynamic>>> _statsCache = {};

  // Standard muscle categories
  static final Map<String, List<String>> muscleCategories = {
    'chest': ['chest'],
    'back': ['middle back', 'lower back', 'lats', 'traps', 'neck'],
    'arms': ['biceps', 'triceps', 'forearms'],
    'abdominals': ['abdominals'],
    'legs': [
      'hamstrings',
      'abductors',
      'quadriceps',
      'calves',
      'glutes',
      'adductors'
    ],
    'shoulders': ['shoulders'],
  };

  // Get the category for a specific muscle
  static String? getCategoryForMuscle(String muscle) {
    for (final category in muscleCategories.keys) {
      if (muscleCategories[category]!.contains(muscle)) {
        return category;
      }
    }
    return null;
  }

  // Load muscle stats for a user with caching
  Future<Map<String, Map<String, dynamic>>> loadMuscleStats(
      String userId) async {
    // Check cache first
    if (_statsCache.containsKey(userId)) {
      print('MuscleProgressService: Using cached stats for user $userId');
      return Map.from(_statsCache[userId]!);
    }

    // Default stats
    final Map<String, Map<String, dynamic>> defaultStats = {
      'chest': {'progress': 0.0, 'level': 1},
      'back': {'progress': 0.0, 'level': 1},
      'arms': {'progress': 0.0, 'level': 1},
      'abdominals': {'progress': 0.0, 'level': 1},
      'legs': {'progress': 0.0, 'level': 1},
      'shoulders': {'progress': 0.0, 'level': 1},
    };

    try {
      print('MuscleProgressService: Loading stats for user $userId');
      final docRef =
          await _firestore.collection('user_stats').doc(userId).get();

      if (docRef.exists) {
        final data = docRef.data();
        if (data != null && data.containsKey('muscleStats')) {
          final stats = data['muscleStats'] as Map<String, dynamic>;
          print('MuscleProgressService: Found existing stats: $stats');

          // Update default stats with stored values
          defaultStats.forEach((muscle, value) {
            if (stats.containsKey(muscle)) {
              defaultStats[muscle] = {
                'progress': (stats[muscle]['progress'] as num).toDouble(),
                'level': (stats[muscle]['level'] as num).toInt(),
              };
            }
          });
        } else {
          print('MuscleProgressService: No muscleStats found in document');
        }
      } else {
        print('MuscleProgressService: User has no stats document yet');
        // Create default stats for this user
        await _firestore.collection('user_stats').doc(userId).set({
          'muscleStats': defaultStats,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Update cache
      _statsCache[userId] = Map.from(defaultStats);

      return defaultStats;
    } catch (e) {
      print('MuscleProgressService: Error loading muscle stats: $e');
      return defaultStats;
    }
  }

  // Update muscle progress based on completed exercises - optimized for performance
  Future<Map<String, Map<String, dynamic>>> updateMuscleProgress({
    required String userId,
    required List<dynamic> primaryMuscles,
    required List<dynamic>? secondaryMuscles,
    required Map<String, Map<String, dynamic>> currentStats,
  }) async {
    print('MuscleProgressService: Updating progress for user $userId');
    print('MuscleProgressService: Primary muscles: $primaryMuscles');
    print('MuscleProgressService: Secondary muscles: $secondaryMuscles');

    // Create a copy of the current stats for local updates
    final updatedStats = Map<String, Map<String, dynamic>>.from(currentStats);
    bool hasChanges = false;

    // Process all muscles in one pass to reduce calculation overhead
    Map<String, double> progressToAdd = {};

    // Process primary muscles - add 0.1 progress
    for (final muscle in primaryMuscles) {
      String muscleStr = muscle.toString();
      for (final category in muscleCategories.keys) {
        if (muscleCategories[category]!.contains(muscleStr)) {
          progressToAdd[category] = (progressToAdd[category] ?? 0) + 0.1;
        }
      }
    }

    // Process secondary muscles - add 0.05 progress
    for (final muscle in secondaryMuscles ?? []) {
      String muscleStr = muscle.toString();
      for (final category in muscleCategories.keys) {
        if (muscleCategories[category]!.contains(muscleStr)) {
          progressToAdd[category] = (progressToAdd[category] ?? 0) + 0.05;
        }
      }
    }

    // Apply updates in memory first for immediate feedback
    for (final category in progressToAdd.keys) {
      if (!updatedStats.containsKey(category)) {
        updatedStats[category] = {'progress': 0.0, 'level': 1};
      }

      double currentProgress =
          (updatedStats[category]!['progress'] as num).toDouble();
      int currentLevel = (updatedStats[category]!['level'] as num).toInt();

      currentProgress += progressToAdd[category]!;

      // Check for level ups
      while (currentProgress >= 1.0) {
        currentLevel += 1;
        currentProgress -= 1.0;
        print(
            'MuscleProgressService: LEVEL UP! $category is now level $currentLevel');
      }

      updatedStats[category] = {
        'progress': currentProgress,
        'level': currentLevel,
      };

      hasChanges = true;
    }

    // Update cache immediately for fast access
    if (hasChanges) {
      _statsCache[userId] = Map.from(updatedStats);
    }

    // Save to Firestore in a transaction for consistency
    try {
      print('MuscleProgressService: Saving updated stats to Firestore');

      // Use a transaction for atomic updates
      await _firestore.runTransaction((transaction) async {
        // Get the current document
        DocumentReference docRef =
            _firestore.collection('user_stats').doc(userId);
        DocumentSnapshot snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          // Update existing document
          transaction.update(docRef, {
            'muscleStats': updatedStats,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new document
          transaction.set(docRef, {
            'muscleStats': updatedStats,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }, maxAttempts: 5, timeout: Duration(seconds: 10));

      print('MuscleProgressService: Stats saved successfully');
    } catch (e) {
      print('MuscleProgressService: Error saving muscle stats: $e');
    }

    return updatedStats;
  }

  // Clear cache for a specific user or all users
  void clearCache([String? userId]) {
    if (userId != null) {
      _statsCache.remove(userId);
    } else {
      _statsCache.clear();
    }
  }
}
