import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness_app/view/achievements/achievements_view.dart';
import 'package:flutter/material.dart';

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update achievements when workout is completed
  Future<void> checkWorkoutAchievements(
      String userId, BuildContext context) async {
    try {
      // Get workout data
      final QuerySnapshot workoutSnapshot = await _firestore
          .collection('workout_history')
          .where('userId', isEqualTo: userId)
          .get();

      final int totalWorkouts = workoutSnapshot.docs.length;

      // Get workout streak from user statistics
      final userStatsDoc =
          await _firestore.collection('user_statistics').doc(userId).get();
      int workoutStreakDays = 0;

      if (userStatsDoc.exists && userStatsDoc.data() != null) {
        final data = userStatsDoc.data()!;
        workoutStreakDays = data['workoutStreak'] as int? ?? 0;
      }

      // Calculate exercise variety
      Set<String> exerciseTypes = {};
      for (var doc in workoutSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('exercises')) {
          final exercises = data['exercises'] as List<dynamic>;
          for (var exercise in exercises) {
            if (exercise is Map<String, dynamic> &&
                exercise.containsKey('name')) {
              exerciseTypes.add(exercise['name'].toString());
            }
          }
        }
      }

      // Get username for the user
      String username = '';
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        username = userDoc.data()!['username'] ?? '';
      }

      // Check for achievements
      _checkFitnessJourneyAchievement(totalWorkouts, userId, username, context);
      _checkExerciseVarietyAchievement(
          exerciseTypes.length, userId, username, context);
      _checkRegularWorkoutAchievement(
          workoutStreakDays, userId, username, context);
    } catch (e) {
      print('Error checking workout achievements: $e');
    }
  }

  // Check for achievement completion
  void _checkFitnessJourneyAchievement(
      int totalWorkouts, String userId, String username, BuildContext context) {
    if (totalWorkouts == 1 || totalWorkouts == 20 || totalWorkouts == 100) {
      String tier = totalWorkouts == 1
          ? 'bronze'
          : (totalWorkouts == 20 ? 'silver' : 'gold');
      _showAchievementPopup('Fitness Journey', tier, context, username);
    }
  }

  void _checkExerciseVarietyAchievement(
      int varietyCount, String userId, String username, BuildContext context) {
    if (varietyCount == 3 || varietyCount == 10 || varietyCount == 15) {
      String tier = varietyCount == 3
          ? 'bronze'
          : (varietyCount == 10 ? 'silver' : 'gold');
      _showAchievementPopup('Exercise Variety', tier, context, username);
    }
  }

  void _checkRegularWorkoutAchievement(
      int streakDays, String userId, String username, BuildContext context) {
    if (streakDays == 5 || streakDays == 30 || streakDays == 100) {
      String tier =
          streakDays == 5 ? 'bronze' : (streakDays == 30 ? 'silver' : 'gold');
      _showAchievementPopup('Regular Workout', tier, context, username);
    }
  }

  // Show achievement popup
  void _showAchievementPopup(String achievementTitle, String tierLevel,
      BuildContext context, String username) {
    // Find the achievement that matches the title from AchievementsView
    final achievements = _createAchievementsList();
    final achievement = achievements.firstWhere(
      (a) => a.title == achievementTitle,
      orElse: () => achievements.first,
    );

    OverlayState? overlayState = Overlay.of(context);
    OverlayEntry? overlayEntry;

    Color getTierColor(String tier) {
      switch (tier) {
        case 'bronze':
          return Color(0xFFCD7F32);
        case 'silver':
          return Color(0xFFC0C0C0);
        case 'gold':
          return Color(0xFFFFD700);
        default:
          return Colors.grey;
      }
    }

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    getTierColor(tierLevel).withOpacity(0.9),
                    getTierColor(tierLevel).withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  )
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      achievement.icon,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              tierLevel == 'bronze'
                                  ? Icons.shield
                                  : tierLevel == 'silver'
                                      ? Icons.star
                                      : Icons.workspace_premium,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "ACHIEVEMENT UNLOCKED!",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          achievement.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "${tierLevel.toUpperCase()} TIER COMPLETED",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Icon(
                        Icons.diamond_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(height: 3),
                      Text(
                        "+${_getTierPoints(tierLevel)}",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Add to overlay and remove after delay
    overlayState.insert(overlayEntry);

    // Add subtle animation and sound here if desired

    Future.delayed(Duration(seconds: 3)).then((value) {
      if (overlayEntry != null) {
        overlayEntry?.remove();
        overlayEntry = null;
      }
    });
  }

  // Helper method to get points for a tier
  int _getTierPoints(String tierLevel) {
    switch (tierLevel) {
      case 'bronze':
        return 50;
      case 'silver':
        return 150;
      case 'gold':
        return 300;
      default:
        return 0;
    }
  }

  // Create a list of achievements (simplified version of the one in AchievementsView)
  List<Achievement> _createAchievementsList() {
    return [
      Achievement(
        title: 'Fitness Journey',
        description: 'Track your workout progression',
        icon: Icons.fitness_center,
        category: 'Workout',
        tiers: [
          TierInfo(
              tier: 'bronze', requirement: 'Complete 1 workout', points: 50),
          TierInfo(
              tier: 'silver', requirement: 'Complete 20 workouts', points: 200),
          TierInfo(
              tier: 'gold', requirement: 'Complete 100 workouts', points: 500),
        ],
      ),
      Achievement(
        title: 'Exercise Variety',
        description: 'Diversify your workout routine',
        icon: Icons.explore,
        category: 'Workout',
        tiers: [
          TierInfo(
              tier: 'bronze',
              requirement: 'Try 3 different exercises',
              points: 50),
          TierInfo(
              tier: 'silver',
              requirement: 'Try 10 different exercises',
              points: 150),
          TierInfo(
              tier: 'gold', requirement: 'Try all exercise types', points: 300),
        ],
      ),
      Achievement(
        title: 'Regular Workout',
        description: 'Establish a consistent workout routine',
        icon: Icons.wb_sunny,
        category: 'Consistency',
        tiers: [
          TierInfo(
              tier: 'bronze',
              requirement: 'Work out 5 days in a row',
              points: 100),
          TierInfo(
              tier: 'silver',
              requirement: 'Work out 30 days in a row',
              points: 300),
          TierInfo(
              tier: 'gold',
              requirement: 'Work out 100 days in a row',
              points: 1000),
        ],
      ),
      // Add more achievements as needed
    ];
  }

  // Check step achievements
  Future<void> checkStepAchievements(String userId, int currentSteps,
      int totalSteps, int stepGoalStreakDays, BuildContext context) async {
    try {
      // Get username for the user
      String username = '';
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        username = userDoc.data()!['username'] ?? '';
      }

      // Check Step Tracker achievements
      _checkStepTrackerAchievement(
          currentSteps, totalSteps, userId, username, context);

      // Check Step Consistency achievements
      _checkStepConsistencyAchievement(
          stepGoalStreakDays, userId, username, context);
    } catch (e) {
      print('Error checking step achievements: $e');
    }
  }

  // Check water intake achievements
  Future<void> checkWaterAchievements(String userId, double currentWaterIntake,
      int waterGoalStreakDays, BuildContext context) async {
    try {
      // Get username for the user
      String username = '';
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        username = userDoc.data()!['username'] ?? '';
      }

      // Check Hydration Hero achievements
      _checkHydrationHeroAchievement(
          currentWaterIntake, userId, username, context);

      // Check Water Consistency achievements
      _checkWaterConsistencyAchievement(
          waterGoalStreakDays, userId, username, context);
    } catch (e) {
      print('Error checking water achievements: $e');
    }
  }

  // Check pose exercise achievements
  Future<void> checkPoseAchievements(
      String userId, int totalPoseExercises, BuildContext context) async {
    try {
      // Get username for the user
      String username = '';
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        username = userDoc.data()!['username'] ?? '';
      }

      // Check Pose Master achievements
      _checkPoseMasterAchievement(
          totalPoseExercises, userId, username, context);
    } catch (e) {
      print('Error checking pose achievements: $e');
    }
  }

  // Individual achievement checks
  void _checkStepTrackerAchievement(int currentSteps, int totalSteps,
      String userId, String username, BuildContext context) {
    if (currentSteps == 5000 ||
        (currentSteps >= 5000 && currentSteps < 10000)) {
      _showAchievementPopup('Step Tracker', 'bronze', context, username);
    } else if (currentSteps == 10000 ||
        (currentSteps >= 10000 && totalSteps < 100000)) {
      _showAchievementPopup('Step Tracker', 'silver', context, username);
    } else if (totalSteps == 100000 || totalSteps > 100000) {
      _showAchievementPopup('Step Tracker', 'gold', context, username);
    }
  }

  void _checkStepConsistencyAchievement(
      int streakDays, String userId, String username, BuildContext context) {
    if (streakDays == 3 || (streakDays > 3 && streakDays < 10)) {
      _showAchievementPopup('Step Consistency', 'bronze', context, username);
    } else if (streakDays == 10 || (streakDays > 10 && streakDays < 30)) {
      _showAchievementPopup('Step Consistency', 'silver', context, username);
    } else if (streakDays == 30 || streakDays > 30) {
      _showAchievementPopup('Step Consistency', 'gold', context, username);
    }
  }

  void _checkHydrationHeroAchievement(double waterIntake, String userId,
      String username, BuildContext context) {
    if (waterIntake == 1000 || (waterIntake > 1000 && waterIntake < 2000)) {
      _showAchievementPopup('Hydration Hero', 'bronze', context, username);
    } else if (waterIntake == 2000 ||
        (waterIntake > 2000 && waterIntake < 3000)) {
      _showAchievementPopup('Hydration Hero', 'silver', context, username);
    } else if (waterIntake == 3000 || waterIntake > 3000) {
      _showAchievementPopup('Hydration Hero', 'gold', context, username);
    }
  }

  void _checkWaterConsistencyAchievement(
      int streakDays, String userId, String username, BuildContext context) {
    if (streakDays == 3 || (streakDays > 3 && streakDays < 10)) {
      _showAchievementPopup('Water Consistency', 'bronze', context, username);
    } else if (streakDays == 10 || (streakDays > 10 && streakDays < 30)) {
      _showAchievementPopup('Water Consistency', 'silver', context, username);
    } else if (streakDays == 30 || streakDays > 30) {
      _showAchievementPopup('Water Consistency', 'gold', context, username);
    }
  }

  void _checkPoseMasterAchievement(int totalExercises, String userId,
      String username, BuildContext context) {
    if (totalExercises == 1 || (totalExercises > 1 && totalExercises < 10)) {
      _showAchievementPopup('Pose Master', 'bronze', context, username);
    } else if (totalExercises == 10 ||
        (totalExercises > 10 && totalExercises < 50)) {
      _showAchievementPopup('Pose Master', 'silver', context, username);
    } else if (totalExercises == 50 || totalExercises > 50) {
      _showAchievementPopup('Pose Master', 'gold', context, username);
    }
  }
}
