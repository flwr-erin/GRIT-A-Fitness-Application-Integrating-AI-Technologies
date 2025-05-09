import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../common/color_extension.dart';

class Achievement {
  final String title;
  final String description;
  final List<TierInfo> tiers;
  int currentTier; // 0 = bronze, 1 = silver, 2 = gold
  final IconData icon;
  final String category;
  double progress; // Value between 0.0 and 1.0

  Achievement({
    required this.title,
    required this.description,
    required this.tiers,
    this.currentTier =
        -1, // -1 means not started, 0 = bronze, 1 = silver, 2 = gold (completed)
    required this.icon,
    required this.category,
    this.progress = 0.0,
  });

  bool get isStarted => currentTier >= 0;
  bool get isCompleted => currentTier >= 2; // Gold completed

  TierInfo get currentTierInfo => currentTier >= 0 && currentTier < tiers.length
      ? tiers[currentTier]
      : tiers.first;

  int get totalPoints =>
      tiers.fold(0, (sum, tier) => sum + (tier.isCompleted ? tier.points : 0));
}

class TierInfo {
  final String tier; // 'bronze', 'silver', 'gold'
  final String requirement;
  final int points;
  final bool isCompleted;

  TierInfo({
    required this.tier,
    required this.requirement,
    required this.points,
    this.isCompleted = false,
  });
}

class AchievementsView extends StatefulWidget {
  final String username;

  AchievementsView({Key? key, required this.username}) : super(key: key);

  @override
  State<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends State<AchievementsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedCategory = 'All';
  final List<String> categories = [
    'All',
    'Workout',
    'Consistency',
    'Progress',
  ];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  int dailyStepGoal = 10000; // Default value
  int currentSteps = 0;
  int totalSteps = 0;
  int stepGoalStreakDays = 0;
  double dailyWaterGoal = 2000; // Default value
  double currentWaterIntake = 0;
  int waterGoalStreakDays = 0;
  int totalPoseExercises = 0;
  int totalWorkouts = 0;
  int workoutStreakDays = 0;
  Set<String> exerciseTypes = {};
  String? userId;
  // Track previously completed tiers to detect new completions
  Map<String, int> previousCompletedTiers = {};
  // Track already notified achievements to prevent repeated notifications
  Set<String> notifiedAchievements = {};

  // Method to save completed achievements to Firestore
  Future<void> _saveCompletedAchievement(
      String achievementTitle, int tier) async {
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('completed_achievements')
          .doc(achievementTitle)
          .set({
        'tierCompleted': tier,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add to notified set to prevent showing again in this session
      notifiedAchievements.add('${achievementTitle}_$tier');
    } catch (e) {
      print('Error saving completed achievement: $e');
    }
  }

  // Load previously completed achievements from Firestore
  Future<void> _loadCompletedAchievements() async {
    if (userId == null) return;

    try {
      final QuerySnapshot completedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('completed_achievements')
          .get();

      for (var doc in completedSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final achievementTitle = doc.id;
        final tierCompleted = data['tierCompleted'] as int? ?? -1;

        // Store in previousCompletedTiers to compare later
        previousCompletedTiers[achievementTitle] = tierCompleted;

        // Add to notified set for all tiers that have been completed
        for (int i = 0; i <= tierCompleted; i++) {
          notifiedAchievements.add('${achievementTitle}_$i');
        }
      }
    } catch (e) {
      print('Error loading completed achievements: $e');
    }
  }

  // Show achievement notification
  void _showAchievementNotification(Achievement achievement, String tierLevel) {
    // Check if this achievement tier has already been notified
    String notificationKey = '${achievement.title}_${achievement.currentTier}';
    if (notifiedAchievements.contains(notificationKey)) {
      return; // Skip notification if already shown
    }

    // Add to notified set
    notifiedAchievements.add(notificationKey);

    // Save to Firestore to persist across sessions
    _saveCompletedAchievement(achievement.title, achievement.currentTier);

    OverlayState? overlayState = Overlay.of(context);
    OverlayEntry overlayEntry;

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
                        "+${achievement.currentTierInfo.points}",
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

    // Add subtle animation and play sound here if desired

    Future.delayed(Duration(seconds: 3)).then((value) {
      overlayEntry.remove();
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Get user ID from username
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        userId = userQuery.docs.first.id;
        await Future.wait([
          _loadStepData(),
          _loadWaterData(),
          _loadPoseExerciseData(),
          _loadWorkoutData(),
          _loadCompletedAchievements(), // Load completed achievements
        ]);

        _updateAchievementProgress();
        setState(() {
          _isLoading = false;
        });
      } else {
        print('User not found for username: ${widget.username}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStepData() async {
    if (userId == null) return;

    try {
      // Get step goal
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        dailyStepGoal = userData['currentStepGoal'] as int? ?? 10000;
      }

      // Get today's step count
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dateStr = DateFormat('yyyy-MM-dd').format(today);

      final stepDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('steps')
          .doc(dateStr)
          .get();

      if (stepDoc.exists && stepDoc.data() != null) {
        currentSteps = stepDoc.data()!['steps'] as int? ?? 0;
      }

      // Get total steps and streak data
      final userStatsDoc =
          await _firestore.collection('user_statistics').doc(userId).get();

      if (userStatsDoc.exists && userStatsDoc.data() != null) {
        final data = userStatsDoc.data()!;
        totalSteps = data['totalSteps'] as int? ?? 0;
        stepGoalStreakDays = data['stepGoalStreak'] as int? ?? 0;
      } else {
        // Calculate step statistics if not already stored
        await _calculateStepStatistics();
      }

      print(
          'Step data loaded - Current: $currentSteps, Total: $totalSteps, Streak: $stepGoalStreakDays');
    } catch (e) {
      print('Error loading step data: $e');
    }
  }

  Future<void> _calculateStepStatistics() async {
    if (userId == null) return;

    try {
      // Get all step records
      final stepDocs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('steps')
          .get();

      int totalCalculatedSteps = 0;
      int maxStreak = 0;
      int currentStreak = 0;
      DateTime? lastStreakDate;

      for (var doc in stepDocs.docs) {
        final data = doc.data();
        final steps = data['steps'] as int? ?? 0;
        final date = DateFormat('yyyy-MM-dd').parse(doc.id);

        totalCalculatedSteps += steps;

        // Check if step goal was met
        if (steps >= dailyStepGoal) {
          if (lastStreakDate == null) {
            currentStreak = 1;
          } else {
            // Check if this is the next day
            final difference = date.difference(lastStreakDate!).inDays;
            if (difference == 1) {
              currentStreak++;
            } else if (difference > 1) {
              // Streak broken
              maxStreak = max(maxStreak, currentStreak);
              currentStreak = 1;
            }
          }
          lastStreakDate = date;
        }
      }

      // Update final streak value
      maxStreak = max(maxStreak, currentStreak);

      // Store calculated statistics
      totalSteps = totalCalculatedSteps;
      stepGoalStreakDays = maxStreak;

      // Save to Firestore for future use
      await _firestore.collection('user_statistics').doc(userId).set({
        'totalSteps': totalSteps,
        'stepGoalStreak': stepGoalStreakDays,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error calculating step statistics: $e');
    }
  }

  Future<void> _loadWaterData() async {
    try {
      // Load user profile to get water goal and current intake
      final userProfileDoc = await _firestore
          .collection('user_profiles')
          .doc(widget.username)
          .get();

      if (userProfileDoc.exists && userProfileDoc.data() != null) {
        final data = userProfileDoc.data()!;

        // Get water intake data
        dailyWaterGoal = (data['waterGoal'] ?? 2000).toDouble();
        currentWaterIntake = (data['waterIntake'] ?? 0).toDouble();

        // Get streak information if available
        waterGoalStreakDays = data['waterGoalStreak'] as int? ?? 0;
      }

      print(
          'Water data loaded - Current: $currentWaterIntake, Goal: $dailyWaterGoal, Streak: $waterGoalStreakDays');
    } catch (e) {
      print('Error loading water intake data: $e');
    }
  }

  Future<void> _loadPoseExerciseData() async {
    if (userId == null) return;

    try {
      // Query pose_exercise_history for completed exercises
      final QuerySnapshot snapshot = await _firestore
          .collection('pose_exercise_history')
          .where('userId', isEqualTo: userId)
          .get();

      totalPoseExercises = snapshot.docs.length;
      print('Pose exercise data loaded - Total exercises: $totalPoseExercises');
    } catch (e) {
      print('Error loading pose exercise data: $e');
    }
  }

  Future<void> _loadWorkoutData() async {
    if (userId == null) return;

    try {
      // Query workout_history for all workouts
      final QuerySnapshot snapshot = await _firestore
          .collection('workout_history')
          .where('userId', isEqualTo: userId)
          .get();

      totalWorkouts = snapshot.docs.length;

      // Track unique exercise types
      for (var doc in snapshot.docs) {
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

      // Get workout streak from user statistics
      final userStatsDoc =
          await _firestore.collection('user_statistics').doc(userId).get();

      if (userStatsDoc.exists && userStatsDoc.data() != null) {
        final data = userStatsDoc.data()!;
        workoutStreakDays = data['workoutStreak'] as int? ?? 0;
      }

      print(
          'Workout data loaded - Total: $totalWorkouts, Types: ${exerciseTypes.length}, Streak: $workoutStreakDays');
    } catch (e) {
      print('Error loading workout data: $e');
    }
  }

  void _updateAchievementProgress() {
    // Initialize previousCompletedTiers on first run if empty
    if (previousCompletedTiers.isEmpty) {
      for (var achievement in achievements) {
        previousCompletedTiers[achievement.title] = -1;
      }
    }

    // Update Step Tracker achievement
    for (var achievement in achievements) {
      // Store the previous tier before updating
      int previousTier = previousCompletedTiers[achievement.title] ?? -1;

      if (achievement.title == 'Step Tracker') {
        if (currentSteps >= 5000) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Reach 5,000 steps in one day',
            points: 50,
            isCompleted: true,
          );
          if (currentSteps >= 10000) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Reach 10,000 steps in one day',
              points: 150,
              isCompleted: true,
            );
            if (totalSteps >= 100000) {
              // Gold tier
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Reach 100,000 total steps',
                points: 300,
                isCompleted: true,
              );
            }
          }
        }
      } else if (achievement.title == 'Step Consistency') {
        if (stepGoalStreakDays >= 3) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Meet daily step goal 3 days in a row',
            points: 75,
            isCompleted: true,
          );
          if (stepGoalStreakDays >= 10) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Meet daily step goal 10 days in a row',
              points: 200,
              isCompleted: true,
            );
            if (stepGoalStreakDays >= 30) {
              // Gold tier
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Meet daily step goal 30 days in a row',
                points: 500,
                isCompleted: true,
              );
            }
          }
        }
      } else if (achievement.title == 'Hydration Hero') {
        if (currentWaterIntake >= 1000) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Drink 1000ml in one day',
            points: 50,
            isCompleted: true,
          );
          if (currentWaterIntake >= 2000) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Drink 2000ml in one day',
              points: 150,
              isCompleted: true,
            );
            if (currentWaterIntake >= 3000) {
              // Gold tier
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Drink 3000ml in one day',
                points: 300,
                isCompleted: true,
              );
            }
          }
        }
      } else if (achievement.title == 'Water Consistency') {
        if (waterGoalStreakDays >= 3) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Meet water goal 3 days in a row',
            points: 75,
            isCompleted: true,
          );
          if (waterGoalStreakDays >= 10) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Meet water goal 10 days in a row',
              points: 200,
              isCompleted: true,
            );
            if (waterGoalStreakDays >= 30) {
              // Gold tier
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Meet water goal 30 days in a row',
                points: 500,
                isCompleted: true,
              );
            }
          }
        }
      } else if (achievement.title == 'Pose Master') {
        if (totalPoseExercises >= 1) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Complete 1 pose detection exercise',
            points: 75,
            isCompleted: true,
          );
          if (totalPoseExercises >= 10) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Complete 10 pose detection exercises',
              points: 200,
              isCompleted: true,
            );
            if (totalPoseExercises >= 50) {
              // Gold tier
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Perfect form in 50 exercises',
                points: 500,
                isCompleted: true,
              );
            }
          }
        }
      } else if (achievement.title == 'Fitness Journey') {
        if (totalWorkouts >= 1) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Complete 1 workout',
            points: 50,
            isCompleted: true,
          );
          if (totalWorkouts >= 20) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Complete 20 workouts',
              points: 200,
              isCompleted: true,
            );
            if (totalWorkouts >= 100) {
              // Gold tier
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Complete 100 workouts',
                points: 500,
                isCompleted: true,
              );
            }
          }
        }
      } else if (achievement.title == 'Exercise Variety') {
        if (exerciseTypes.length >= 3) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Try 3 different exercises',
            points: 50,
            isCompleted: true,
          );
          if (exerciseTypes.length >= 10) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Try 10 different exercises',
              points: 150,
              isCompleted: true,
            );
            if (exerciseTypes.length >= 15) {
              // Gold tier - assuming 15 is "all" exercise types
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Try all exercise types',
                points: 300,
                isCompleted: true,
              );
            }
          }
        }
      } else if (achievement.title == 'Regular Workout') {
        if (workoutStreakDays >= 5) {
          // Bronze tier
          achievement.tiers[0] = TierInfo(
            tier: 'bronze',
            requirement: 'Work out 5 days in a row',
            points: 100,
            isCompleted: true,
          );
          if (workoutStreakDays >= 30) {
            // Silver tier
            achievement.tiers[1] = TierInfo(
              tier: 'silver',
              requirement: 'Work out 30 days in a row',
              points: 300,
              isCompleted: true,
            );
            if (workoutStreakDays >= 100) {
              // Gold tier
              achievement.tiers[2] = TierInfo(
                tier: 'gold',
                requirement: 'Work out 100 days in a row',
                points: 1000,
                isCompleted: true,
              );
            }
          }
        }
      }

      // Update currentTier for each achievement
      int completedTiers = 0;
      for (var tier in achievement.tiers) {
        if (tier.isCompleted) completedTiers++;
      }
      achievement.currentTier = completedTiers -
          1; // -1 if none completed, 0 = bronze, 1 = silver, 2 = gold

      // Check if the tier has increased and trigger notification
      if (achievement.currentTier > previousTier &&
          achievement.currentTier >= 0) {
        String tierLevel = achievement.currentTier == 0
            ? 'bronze'
            : achievement.currentTier == 1
                ? 'silver'
                : 'gold';

        // Show notification for the newly completed tier
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAchievementNotification(achievement, tierLevel);
        });
      }

      // Save the current tier for next comparison
      previousCompletedTiers[achievement.title] = achievement.currentTier;

      // Update progress based on current tier
      if (achievement.currentTier >= 0 && achievement.currentTier < 2) {
        if (achievement.title == 'Step Tracker') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = currentSteps / 10000;
          } else {
            // Progress to Gold
            achievement.progress = totalSteps / 100000;
          }
        } else if (achievement.title == 'Step Consistency') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = stepGoalStreakDays / 10;
          } else {
            // Progress to Gold
            achievement.progress = stepGoalStreakDays / 30;
          }
        } else if (achievement.title == 'Hydration Hero') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = currentWaterIntake / 2000;
          } else {
            // Progress to Gold
            achievement.progress = currentWaterIntake / 3000;
          }
        } else if (achievement.title == 'Water Consistency') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = waterGoalStreakDays / 10;
          } else {
            // Progress to Gold
            achievement.progress = waterGoalStreakDays / 30;
          }
        } else if (achievement.title == 'Pose Master') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = totalPoseExercises / 10;
          } else {
            // Progress to Gold
            achievement.progress = totalPoseExercises / 50;
          }
        } else if (achievement.title == 'Fitness Journey') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = totalWorkouts / 20;
          } else {
            // Progress to Gold
            achievement.progress = totalWorkouts / 100;
          }
        } else if (achievement.title == 'Exercise Variety') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = exerciseTypes.length / 10;
          } else {
            // Progress to Gold
            achievement.progress = exerciseTypes.length / 15;
          }
        } else if (achievement.title == 'Regular Workout') {
          if (achievement.currentTier == 0) {
            // Progress to Silver
            achievement.progress = workoutStreakDays / 30;
          } else {
            // Progress to Gold
            achievement.progress = workoutStreakDays / 100;
          }
        }

        // Clamp progress between 0.0 and 1.0
        achievement.progress = achievement.progress.clamp(0.0, 1.0);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<Achievement> achievements = [
    // Workout Category
    Achievement(
      title: 'Fitness Journey',
      description: 'Track your workout progression',
      icon: Icons.fitness_center,
      category: 'Workout',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Complete 1 workout',
          points: 50,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Complete 20 workouts',
          points: 200,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Complete 100 workouts',
          points: 500,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),
    Achievement(
      title: 'Pose Master',
      description: 'Perfect your exercise form',
      icon: Icons.accessibility_new,
      category: 'Workout',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Complete 1 pose detection exercise',
          points: 75,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Complete 10 pose detection exercises',
          points: 200,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Perfect form in 50 exercises',
          points: 500,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),
    Achievement(
      title: 'Exercise Variety',
      description: 'Diversify your workout routine',
      icon: Icons.explore,
      category: 'Workout',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Try 3 different exercises',
          points: 50,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Try 10 different exercises',
          points: 150,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Try all exercise types',
          points: 300,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),

    // Step Tracking
    Achievement(
      title: 'Step Tracker',
      description: 'Achieve step milestones',
      icon: Icons.directions_walk,
      category: 'Progress',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Reach 5,000 steps in one day',
          points: 50,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Reach 10,000 steps in one day',
          points: 150,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Reach 100,000 total steps',
          points: 300,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),

    Achievement(
      title: 'Step Consistency',
      description: 'Maintain daily step goals',
      icon: Icons.trending_up,
      category: 'Consistency',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Meet daily step goal 3 days in a row',
          points: 75,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Meet daily step goal 10 days in a row',
          points: 200,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Meet daily step goal 30 days in a row',
          points: 500,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),

    // Water Tracking
    Achievement(
      title: 'Hydration Hero',
      description: 'Track your water intake',
      icon: Icons.water_drop,
      category: 'Progress',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Drink 1000ml in one day',
          points: 50,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Drink 2000ml in one day',
          points: 150,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Drink 3000ml in one day',
          points: 300,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),

    Achievement(
      title: 'Water Consistency',
      description: 'Maintain daily water intake habits',
      icon: Icons.local_drink,
      category: 'Consistency',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Meet water goal 3 days in a row',
          points: 75,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Meet water goal 10 days in a row',
          points: 200,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Meet water goal 30 days in a row',
          points: 500,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),

    // Consistency Category
    Achievement(
      title: 'Regular Workout',
      description: 'Establish a consistent workout routine',
      icon: Icons.wb_sunny,
      category: 'Consistency',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Work out 5 days in a row',
          points: 100,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Work out 30 days in a row',
          points: 300,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Work out 100 days in a row',
          points: 1000,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),
    Achievement(
      title: 'Workout Frequency',
      description: 'Regular workout schedule',
      icon: Icons.calendar_month,
      category: 'Consistency',
      currentTier: -1, // Will be set based on data
      progress: 0.0, // Will be calculated based on actual data
      tiers: [
        TierInfo(
          tier: 'bronze',
          requirement: 'Complete 10 workouts in one month',
          points: 100,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'silver',
          requirement: 'Complete 20 workouts in one month',
          points: 250,
          isCompleted: false, // Will be updated based on actual data
        ),
        TierInfo(
          tier: 'gold',
          requirement: 'Complete 30 workouts in one month',
          points: 500,
          isCompleted: false, // Will be updated based on actual data
        ),
      ],
    ),
  ];

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

  int getTotalPoints() {
    return achievements.fold(0, (sum, a) => sum + a.totalPoints);
  }

  int getCompletedAchievements() {
    return achievements.where((a) => a.isCompleted).length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredAchievements = selectedCategory == 'All'
        ? achievements
        : achievements.where((a) => a.category == selectedCategory).toList();

    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.primary,
        elevation: 0,
        title: Text(
          'ACHIEVEMENTS',
          style: TextStyle(
            color: TColor.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TColor.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // User stats card with game-like design
          Container(
            decoration: BoxDecoration(
              color: TColor.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: EdgeInsets.only(bottom: 20),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.4)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Player level and info
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "${getTotalPoints() ~/ 500 + 1}",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.username,
                                style: TextStyle(
                                  color: TColor.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Level ${getTotalPoints() ~/ 500 + 1} Fitness Warrior",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.diamond_outlined,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    '${getTotalPoints()} Points',
                                    style: TextStyle(
                                      color: TColor.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Achievement progress
                      Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 55,
                                height: 55,
                                child: CircularProgressIndicator(
                                  value: getCompletedAchievements() /
                                      achievements.length,
                                  backgroundColor: Colors.white30,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.amber),
                                  strokeWidth: 8,
                                ),
                              ),
                              Text(
                                '${getCompletedAchievements()}',
                                style: TextStyle(
                                  color: TColor.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Text(
                            '${achievements.length} Quests',
                            style: TextStyle(
                              color: TColor.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  // Experience bar to next level
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "LEVEL ${getTotalPoints() ~/ 500 + 1}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "LEVEL ${getTotalPoints() ~/ 500 + 2}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (getTotalPoints() % 500) / 500,
                          minHeight: 10,
                          backgroundColor: Colors.white12,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${getTotalPoints() % 500} / 500 XP",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            "${500 - (getTotalPoints() % 500)} XP to next level",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Category Tabs - Gamified
          Container(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == selectedCategory;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
                      _tabController.animateTo(index);
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? TColor.primary : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color:
                            isSelected ? TColor.primary : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: TColor.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        children: [
                          Icon(
                            category == 'All'
                                ? Icons.grid_view
                                : category == 'Workout'
                                    ? Icons.fitness_center
                                    : category == 'Consistency'
                                        ? Icons.repeat
                                        : Icons.trending_up,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            category,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Achievement list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredAchievements.length,
              itemBuilder: (context, index) {
                final achievement = filteredAchievements[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: achievement.isCompleted
                          ? [
                              getTierColor('gold').withOpacity(0.3),
                              getTierColor('gold').withOpacity(0.1)
                            ]
                          : achievement.isStarted
                              ? [
                                  getTierColor(achievement.currentTierInfo.tier)
                                      .withOpacity(0.3),
                                  getTierColor(achievement.currentTierInfo.tier)
                                      .withOpacity(0.1)
                                ]
                              : [Colors.grey.shade200, Colors.grey.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: achievement.isStarted
                            ? getTierColor(achievement.currentTierInfo.tier)
                                .withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: achievement.isStarted
                          ? getTierColor(achievement.currentTierInfo.tier)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: achievement.isStarted
                            ? getTierColor(achievement.currentTierInfo.tier)
                                .withOpacity(0.2)
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: achievement.isStarted
                              ? getTierColor(achievement.currentTierInfo.tier)
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        achievement.icon,
                        color: achievement.isStarted
                            ? getTierColor(achievement.currentTierInfo.tier)
                            : Colors.grey.shade600,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      achievement.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: achievement.isStarted
                            ? getTierColor(achievement.currentTierInfo.tier)
                                .withOpacity(0.8)
                            : Colors.grey.shade700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.description,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Current tier progress bar
                        if (achievement.isStarted &&
                            achievement.currentTier < 2) ...[
                          Row(
                            children: [
                              Icon(
                                achievement.currentTierInfo.tier == 'bronze'
                                    ? Icons.shield
                                    : achievement.currentTierInfo.tier ==
                                            'silver'
                                        ? Icons.star
                                        : Icons.workspace_premium,
                                color: getTierColor(
                                    achievement.currentTierInfo.tier),
                                size: 15,
                              ),
                              SizedBox(width: 5),
                              Text(
                                "${achievement.currentTierInfo.tier.toUpperCase()} → ${achievement.currentTier < 1 ? 'SILVER' : 'GOLD'}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: getTierColor(
                                      achievement.currentTierInfo.tier),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: achievement.progress,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                getTierColor(achievement.currentTierInfo.tier),
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ] else if (!achievement.isStarted) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 15,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(width: 5),
                              Text(
                                "Not started",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ] else if (achievement.isCompleted) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                size: 15,
                                color: getTierColor('gold'),
                              ),
                              SizedBox(width: 5),
                              Text(
                                "GOLD TIER COMPLETE!",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: getTierColor('gold'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: achievement.isStarted
                            ? getTierColor(achievement.currentTierInfo.tier)
                                .withOpacity(0.2)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: achievement.isStarted
                              ? getTierColor(achievement.currentTierInfo.tier)
                              : Colors.grey.shade400,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.diamond_outlined,
                            size: 15,
                            color: achievement.isStarted
                                ? getTierColor(achievement.currentTierInfo.tier)
                                : Colors.grey.shade600,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '${achievement.totalPoints}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: achievement.isStarted
                                  ? getTierColor(
                                      achievement.currentTierInfo.tier)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PROGRESSION PATH",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 12),
                            for (int i = 0; i < achievement.tiers.length; i++)
                              _buildTierRow(
                                achievement.tiers[i],
                                isActive: i <= achievement.currentTier,
                                isCurrent: i == achievement.currentTier,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow(TierInfo tier,
      {required bool isActive, required bool isCurrent}) {
    final tierColor = getTierColor(tier.tier);

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? tierColor.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? tierColor : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? tierColor : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              tier.tier == 'bronze'
                  ? Icons.shield
                  : tier.tier == 'silver'
                      ? Icons.star
                      : Icons.workspace_premium,
              color: Colors.white,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.tier.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive ? tierColor : Colors.grey,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  tier.requirement,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? tierColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.diamond_outlined,
                  color: Colors.white,
                  size: 12,
                ),
                SizedBox(width: 2),
                Text(
                  '${tier.points}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          if (tier.isCompleted)
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            )
          else if (isCurrent)
            Icon(
              Icons.hourglass_top,
              color: tierColor,
              size: 20,
            )
          else if (!isActive)
            Icon(
              Icons.lock,
              color: Colors.grey,
              size: 20,
            ),
        ],
      ),
    );
  }
}
