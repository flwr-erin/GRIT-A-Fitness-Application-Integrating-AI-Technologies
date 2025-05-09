import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:fitness_app/services/muscle_stats_listener.dart';
import 'package:fitness_app/view/exercise_view.dart';
import 'package:fitness_app/view/dailychal/dailychal_view.dart';
import 'package:fitness_app/view/quick_start_view.dart';
import 'package:fitness_app/view/workout_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../common/color_extension.dart';
import '../../common/exercise_detail_view.dart';
import '../menu/menu_view.dart';
import '../training_stats_view.dart';
import '../weight_view.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeView extends StatefulWidget {
  final String username;
  const HomeView({super.key, required this.username});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  int currentSteps = 0; // Changed from hardcoded 6000 to 0
  int todayStepCount = 0;
  int dailyLimit = 10000;
  int currentPage = 0;

  // Step counter stream
  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;
  String _status = 'inactive', _steps = '0';
  DateTime? _lastUpdateTime;

  // Track step data for persistence
  DateTime _todayDate = DateTime.now();
  Map<String, int> _dailyStepCounts = {};

  double userHeight = 0;
  double userWeight = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int streakCount = 0;
  DateTime? lastCompletionDate;

  String? userId;

  String userFitnessLevel =
      'beginner'; // Add this line at the top with other variables

  double dailyWaterGoal = 2000; // Default 2000ml
  double currentWaterIntake = 0;
  List<double> commonServingSizes = [250, 500, 750, 1000]; // in ml

  List<Map<String, dynamic>> waterServings = [
    {'amount': 250, 'icon': Icons.local_cafe_outlined, 'label': 'S'},
    {'amount': 500, 'icon': Icons.coffee_outlined, 'label': 'M'},
    {'amount': 750, 'icon': Icons.local_drink_outlined, 'label': 'L'},
    {'amount': 1000, 'icon': Icons.water_drop_outlined, 'label': 'XL'},
  ];

  Map<String, Map<String, dynamic>> muscleStats = {
    'chest': {'progress': 0.0, 'level': 1},
    'back': {'progress': 0.0, 'level': 1},
    'arms': {'progress': 0.0, 'level': 1},
    'abdominals': {'progress': 0.0, 'level': 1},
    'legs': {'progress': 0.0, 'level': 1},
    'shoulders': {'progress': 0.0, 'level': 1},
  };

  final Map<String, List<String>> muscleCategories = {
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

  MuscleStatsListener? _muscleStatsListener;

  final Map<String, Map<String, dynamic>> rankRequirements = {
    'Beginner': {'maxLevel': 10, 'nextRank': 'Novice'},
    'Novice': {'maxLevel': 20, 'nextRank': 'Intermediate'},
    'Intermediate': {'maxLevel': 40, 'nextRank': 'Advanced'},
    'Advanced': {'maxLevel': 60, 'nextRank': 'Expert'},
    'Expert': {'maxLevel': 80, 'nextRank': 'Master'},
    'Master': {'maxLevel': 100, 'nextRank': null},
  };

  // Add a property to store water intake history
  List<Map<String, dynamic>> waterIntakeHistory = [];

  // Add this new field to store step history
  List<Map<String, dynamic>> stepHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    userHeight = 0;
    userWeight = 0;
    _loadUserProfile();
    _loadUserData();
    _setupPeriodicRefresh();
    _loadWaterIntakeHistory(); // Add this line to load history on init

    // Initialize step counter
    _initPedometer();
    _loadStepData();
    _loadStepHistory(); // Add this line to load step history on init

    // Add listener for fitness level changes
    _setupFitnessLevelListener();
  }

  // Add this method to listen for fitness level updates
  void _setupFitnessLevelListener() {
    if (widget.username.isEmpty) return;

    _firestore
        .collection('user_profiles')
        .doc(widget.username)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('fitnessLevel')) {
          int fitnessLevelValue = data['fitnessLevel'] ?? 0;
          final fitnessLevels = {0: 'beginner', 1: 'intermediate', 2: 'expert'};

          setState(() {
            userFitnessLevel = fitnessLevels[fitnessLevelValue] ?? 'beginner';
          });

          print('Fitness level updated: $userFitnessLevel');
        }
      }
    });
  }

  // Request activity permission
  Future<void> _requestActivityPermission() async {
    var status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _initPedometerStreams();
    } else {
      print('Activity recognition permission not granted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Step counting requires activity permission'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  // Initialize pedometer
  void _initPedometer() async {
    await _requestActivityPermission();

    // Load existing data first
    if (userId != null) {
      await _loadStepData();
    }
  }

  void _initPedometerStreams() {
    _stepCountStream = Pedometer.stepCountStream;
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;

    _stepCountStream?.listen(_onStepCount).onError(_onStepCountError);
    _pedestrianStatusStream
        ?.listen(_onPedestrianStatusChanged)
        .onError(_onPedestrianStatusError);
  }

  // Handle step count updates
  void _onStepCount(StepCount event) {
    final String steps = event.steps.toString();
    final DateTime timeStamp = event.timeStamp;

    // Make sure we have today's date
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final String todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Initialize last update time if it's null
    _lastUpdateTime ??= timeStamp;

    // If day changed, reset and save yesterday's data
    if (!DateUtils.isSameDay(_todayDate, today)) {
      print(
          'Day changed from ${_todayDate.toString()} to ${today.toString()}, saving steps and resetting');
      _saveStepData(_todayDate, todayStepCount);
      todayStepCount = 0;
      _todayDate = today;
      _dailyStepCounts.clear(); // Clear cached counts for the new day
    }

    // Process new step data
    if (_lastUpdateTime!.isBefore(timeStamp)) {
      int newTotalSteps = event.steps;
      int stepDelta = 0;

      // If we have previous steps recorded today
      if (_dailyStepCounts.containsKey(todayStr)) {
        // Calculate the difference since last update
        int previousTotalSteps = int.parse(_steps);
        stepDelta = newTotalSteps - previousTotalSteps;

        // Handle potential device reboot or pedometer reset
        if (stepDelta < 0) {
          print(
              'Negative step delta detected (device may have rebooted): $stepDelta');
          stepDelta = newTotalSteps; // Just use new steps as delta in this case
        }
      } else {
        // First update of the day
        stepDelta = newTotalSteps;
        print('First step update of the day: $stepDelta steps');
      }

      // Update total steps for today
      todayStepCount += stepDelta;
      _dailyStepCounts[todayStr] = todayStepCount;

      // Save updated step count immediately
      _saveStepData(today, todayStepCount);

      // Update UI
      setState(() {
        _lastUpdateTime = timeStamp;
        _steps = newTotalSteps.toString();
        currentSteps = todayStepCount;

        // Check if goal reached
        if (currentSteps >= dailyLimit && stepDelta > 0) {
          checkAndUpdateStreak();
        }
      });

      print(
          'Updated step count: current=$currentSteps, total today=$todayStepCount');
    }
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    setState(() {
      _status = event.status;
    });
  }

  void _onStepCountError(error) {
    print('Step count error: $error');
    setState(() {
      _steps = 'Step count not available';
    });
  }

  void _onPedestrianStatusError(error) {
    print('Pedestrian status error: $error');
    setState(() {
      _status = 'Pedestrian status not available';
    });
  }

  // Save step data to Firestore
  Future<void> _saveStepData(DateTime date, int steps) async {
    if (userId == null) {
      print('Cannot save step data: userId is null');
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      print('Saving $steps steps for date $dateStr with goal $dailyLimit');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('steps')
          .doc(dateStr)
          .set(
              {
            'date': Timestamp.fromDate(date),
            'steps': steps,
            'goal': dailyLimit,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
              SetOptions(
                  merge:
                      true)); // Use merge to prevent overwriting existing data

      // Also update the user's current step goal in the main user document
      // This ensures the goal persists across multiple days
      await _firestore.collection('users').doc(userId).update({
        'currentStepGoal': dailyLimit,
      });

      _dailyStepCounts[dateStr] = steps;

      // After saving, refresh the step history
      _loadStepHistory();
    } catch (e) {
      print('Error saving step data: $e');
    }
  }

  // Load step data from Firestore
  Future<void> _loadStepData() async {
    if (userId == null) {
      print('Cannot load step data: userId is null');
      return;
    }

    try {
      // First, get the user's persistent step goal
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        if (userData.containsKey('currentStepGoal')) {
          setState(() {
            dailyLimit = userData['currentStepGoal'] as int? ?? 10000;
          });
          print('Loaded persistent step goal: $dailyLimit');
        }
      }

      // Then load today's step data
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dateStr = DateFormat('yyyy-MM-dd').format(today);

      print('Loading step data for $dateStr');
      // Get today's step data
      final stepDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('steps')
          .doc(dateStr)
          .get();

      if (stepDoc.exists && stepDoc.data() != null) {
        final steps = stepDoc.data()!['steps'] as int? ?? 0;

        print('Found existing step data: $steps steps');

        setState(() {
          todayStepCount = steps;
          currentSteps = steps;
          _steps = steps.toString();
          _dailyStepCounts[dateStr] = steps;
        });
      } else {
        print('No step data found for today');
      }

      // Also load streak data
      _loadStreakData();

      // And load step history
      _loadStepHistory();
    } catch (e) {
      print('Error loading step data: $e');
    }
  }

  // Load streak data - Removed the dailyLimit update here to avoid overriding the persistent setting
  Future<void> _loadStreakData() async {
    if (userId == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final savedStreak = data['stepStreak'] as int? ?? 0;
        final lastCompletionStr = data['lastStepGoalCompletion'] as String?;

        setState(() {
          streakCount = savedStreak;
          if (lastCompletionStr != null) {
            lastCompletionDate = DateTime.parse(lastCompletionStr);
          }
          // We don't set dailyLimit here anymore as it's handled in _loadStepData
        });
      }
    } catch (e) {
      print('Error loading streak data: $e');
    }
  }

  Timer? _refreshTimer;
  void _setupPeriodicRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted) {
        print('Running periodic refresh of muscle stats');
        _loadMuscleStats();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserProfile();
      // Reinitialize pedometer when app is resumed
      _initPedometerStreams();
      _loadStepData();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfileDoc = await _firestore
          .collection('user_profiles')
          .doc(widget.username)
          .get();

      if (userProfileDoc.exists) {
        final data = userProfileDoc.data()!;
        if (mounted) {
          setState(() {
            try {
              String heightStr = (data['height'] ?? '0 cm').toString();
              String weightStr = (data['weight'] ?? '0 kg').toString();

              userHeight = double.tryParse(heightStr.split(' ')[0]) ?? 0;
              userWeight = double.tryParse(weightStr.split(' ')[0]) ?? 0;

              int fitnessLevelValue = data['fitnessLevel'] ?? 0;
              final fitnessLevels = {
                0: 'beginner',
                1: 'intermediate',
                2: 'expert'
              };
              userFitnessLevel = fitnessLevels[fitnessLevelValue] ?? 'beginner';

              currentWaterIntake = (data['waterIntake'] ?? 0).toDouble();
              DateTime? lastUpdate = data['lastWaterUpdate']?.toDate();

              if (lastUpdate != null &&
                  !DateUtils.isSameDay(lastUpdate, DateTime.now())) {
                // Save yesterday's water intake to history before resetting
                if (currentWaterIntake > 0) {
                  _saveDailyWaterIntake(currentWaterIntake, lastUpdate);
                }

                // Reset water intake for today
                currentWaterIntake = 0;
                _updateWaterIntakeInDatabase();
              }

              calculateWaterGoal();
            } catch (e) {
              print('Error parsing height/weight: $e');
              userHeight = 0;
              userWeight = 0;
              userFitnessLevel = 'beginner';
            }
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          userHeight = 0;
          userWeight = 0;
          userFitnessLevel = 'beginner';
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        setState(() {
          userId = userQuery.docs.first.id;
        });
        await _loadMuscleStats();
        _listenForWorkoutCompletion();
        _loadStepData(); // Load step data after we have userId
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadMuscleStats() async {
    if (userId == null) return;

    try {
      print('Loading muscle stats for user: $userId');
      final docRef =
          await _firestore.collection('user_stats').doc(userId).get();

      if (docRef.exists) {
        final data = docRef.data();
        if (data != null && data.containsKey('muscleStats')) {
          final previousStats =
              Map<String, Map<String, dynamic>>.from(muscleStats);
          setState(() {
            final stats = data['muscleStats'] as Map<String, dynamic>;
            print('Received muscle stats from database: $stats');

            muscleStats.forEach((muscle, value) {
              if (stats.containsKey(muscle)) {
                try {
                  double progress =
                      (stats[muscle]['progress'] as num).toDouble();
                  int level = (stats[muscle]['level'] as num).toInt();
                  print('Setting $muscle - progress: $progress, level: $level');

                  muscleStats[muscle] = {
                    'progress': progress,
                    'level': level,
                  };
                } catch (e) {
                  print('Error parsing stats for $muscle: $e');
                }
              }
            });
          });

          if (_muscleStatsListener != null) {
            await _muscleStatsListener!.checkForLevelUps(muscleStats);
          }
        } else {
          print('No muscleStats field found in document');
        }
      } else {
        print('Creating default user_stats document for user: $userId');
        await _firestore.collection('user_stats').doc(userId).set({
          'muscleStats': muscleStats,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error loading muscle stats: $e');
    }
  }

  void _listenForWorkoutCompletion() {
    if (userId == null) return;

    _muscleStatsListener =
        MuscleStatsListener(userId: userId!, context: context);
    _muscleStatsListener?.initialize(muscleStats);

    print('Starting workout completion listener for user: $userId');

    // Modify the listener to handle real-time updates more efficiently
    _firestore
        .collection('workout_history')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final latestWorkout = snapshot.docs.first.data();
        print(
            'Received workout update: ${latestWorkout['id'] ?? 'unknown ID'}');
        final exercises = latestWorkout['exercises'] as List<dynamic>?;

        if (exercises != null &&
            exercises.isNotEmpty &&
            latestWorkout['statsProcessed'] != true) {
          print(
              'Processing unprocessed workout with ${exercises.length} exercises');

          // Show a loading indicator for immediate feedback
          _showUpdatingStatsIndicator();

          try {
            // Process the workout and update stats immediately - optimized version
            final updatedStats = await _updateMuscleStats(exercises);

            // Apply new stats to UI immediately
            setState(() {
              muscleStats = updatedStats;
            });

            // Mark the workout as processed in the background
            _firestore
                .collection('workout_history')
                .doc(snapshot.docs.first.id)
                .update({'statsProcessed': true})
                .then((_) => print('Workout processed and marked as complete'))
                .catchError(
                    (e) => print('Error marking workout as processed: $e'));

            print('Workout processed and stats updated immediately');

            // Show success notification
            _showStatsUpdatedNotification();
          } catch (e) {
            print('Error updating muscle stats: $e');
            // Show error notification
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating stats. Please try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }, onError: (e) {
      print('Error listening for workouts: $e');
    });
  }

  // Add this method to show a loading indicator while stats are updating
  void _showUpdatingStatsIndicator() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Updating your stats...'),
          ],
        ),
        backgroundColor: TColor.primary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Add this method to show a success notification
  void _showStatsUpdatedNotification() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 16),
            Text('Stats updated successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Optimized to avoid loading stats after update
  Future<Map<String, Map<String, dynamic>>> _updateMuscleStats(
      List<dynamic> exercises) async {
    if (userId == null) return muscleStats;

    print('Updating muscle stats for ${exercises.length} exercises');
    Map<String, double> progressToAdd = {};

    // Process all exercises to determine total progress
    for (final exercise in exercises) {
      final primaryMuscles = exercise['primaryMuscles'] as List<dynamic>? ?? [];
      final secondaryMuscles =
          exercise['secondaryMuscles'] as List<dynamic>? ?? [];

      for (final muscle in primaryMuscles) {
        for (final category in muscleCategories.keys) {
          if (muscleCategories[category]!.contains(muscle)) {
            progressToAdd[category] = (progressToAdd[category] ?? 0) + 0.1;
          }
        }
      }

      for (final muscle in secondaryMuscles) {
        for (final category in muscleCategories.keys) {
          if (muscleCategories[category]!.contains(muscle)) {
            progressToAdd[category] = (progressToAdd[category] ?? 0) + 0.05;
          }
        }
      }
    }

    // Create a local copy to update so we can immediately reflect changes in UI
    final updatedStats = Map<String, Map<String, dynamic>>.from(muscleStats);

    // Apply all updates locally first
    progressToAdd.forEach((category, progress) {
      double currentProgress = updatedStats[category]?['progress'] ?? 0.0;
      int currentLevel = updatedStats[category]?['level'] ?? 1;

      currentProgress += progress;
      while (currentProgress >= 1.0) {
        currentLevel++;
        currentProgress -= 1.0;
      }

      updatedStats[category] = {
        'progress': currentProgress,
        'level': currentLevel,
      };
    });

    try {
      // Only perform DB update in the background - don't await
      _firestore.collection('user_stats').doc(userId).set({
        'muscleStats': updatedStats,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving muscle stats: $e');
      // Continue anyway since we've updated the UI already
    }

    return updatedStats;
  }

  double calculateBMI() {
    if (userHeight <= 0 || userWeight <= 0) return 0;
    return userWeight / ((userHeight / 100) * (userHeight / 100));
  }

  String getBMICategory(double bmi) {
    if (bmi <= 0) return 'N/A';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  void updateSteps(int steps) {
    final previousSteps = currentSteps;
    setState(() {
      currentSteps = steps;
      if (currentSteps >= dailyLimit && previousSteps < dailyLimit) {
        checkAndUpdateStreak();
      }
    });
  }

  void checkAndUpdateStreak() {
    if (currentSteps >= dailyLimit) {
      final today = DateTime.now();
      if (lastCompletionDate != null) {
        final difference = today.difference(lastCompletionDate!).inDays;
        if (difference == 1) {
          // Consecutive day
          setState(() {
            streakCount++;

            // Check if streak reaches a milestone for automatic goal increase
            if (streakCount % 5 == 0) {
              _handleStreakMilestone();
            }
          });
        } else if (difference > 1) {
          // Streak broken
          setState(() {
            streakCount = 1;
          });
        }
      } else {
        // First completion
        setState(() {
          streakCount = 1;
        });
      }

      // Update last completion date and save streak
      lastCompletionDate = today;
      _saveStreakData(streakCount, today);
    }
  }

  // Add this new method for handling streak milestones
  void _handleStreakMilestone() {
    // Find next achievement level for the step goal
    int currentGoal = dailyLimit;
    int nextGoal = currentGoal;
    String nextTitle = "";
    Color nextColor = Colors.blue;

    // Define possible step goal levels (same as in the achievement levels)
    final List<Map<String, dynamic>> stepLevels = [
      {'steps': 2000, 'title': 'Starter', 'color': Colors.green},
      {'steps': 4000, 'title': 'Walker', 'color': Colors.blue},
      {'steps': 6000, 'title': 'Mover', 'color': Colors.orange},
      {'steps': 8000, 'title': 'Athlete', 'color': Colors.purple},
      {'steps': 10000, 'title': 'Champion', 'color': Colors.amber},
      {'steps': 12000, 'title': 'Warrior', 'color': Colors.red},
    ];

    // Find the next level based on current goal
    for (int i = 0; i < stepLevels.length - 1; i++) {
      if (currentGoal == stepLevels[i]['steps']) {
        nextGoal = stepLevels[i + 1]['steps'];
        nextTitle = stepLevels[i + 1]['title'];
        nextColor = stepLevels[i + 1]['color'];
        break;
      }
    }

    // Only increase if there's a next level
    if (nextGoal > currentGoal) {
      setState(() {
        dailyLimit = nextGoal;
      });

      // Save the new goal to Firestore for persistence
      if (userId != null) {
        // Update the main user document for persistent goal
        _firestore.collection('users').doc(userId).update({
          'currentStepGoal': nextGoal,
        }).then((_) {
          print(
              'Updated persistent step goal to $nextGoal due to streak milestone');
          // Also update today's record
          final today = DateTime.now();
          _saveStepData(today, currentSteps);
        }).catchError((e) {
          print('Error updating persistent step goal: $e');
        });
      }

      // Show notification about goal increase
      _showGoalIncreaseNotification(nextGoal, nextTitle, nextColor);
    }
  }

  // Add this method to show a notification when goal increases
  void _showGoalIncreaseNotification(int newGoal, String title, Color color) {
    if (!mounted) return;

    // Calculate how much the goal increased
    int increase = newGoal - (newGoal > 2000 ? newGoal - 2000 : 0);

    // Show a fun, gamified notification
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 300,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.9),
                  color,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy or achievement icon
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "LEVEL UP!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "5-Day Streak Achievement",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "Your daily step goal has increased to $newGoal steps!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "You've unlocked the \"$title\" tier!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 25),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      "AWESOME!",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Also show a snackbar as a reminder when they close the dialog
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: color,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.arrow_upward, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "5-day streak! Your daily step goal is now $newGoal steps.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  // Save streak data to Firestore - Update to include current goal
  Future<void> _saveStreakData(int streak, DateTime completionDate) async {
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'stepStreak': streak,
        'lastStepGoalCompletion': completionDate.toString(),
        'currentStepGoal': dailyLimit, // Add this line to save current goal
      });
    } catch (e) {
      print('Error saving streak data: $e');
    }
  }

  void changeDailyLimit() {
    int selectedLimit = dailyLimit;
    double sliderValue = dailyLimit / 1000;

    // Define achievement badges with their descriptions
    final List<Map<String, dynamic>> achievementLevels = [
      {
        'steps': 2000,
        'title': 'Starter',
        'icon': Icons.directions_walk,
        'color': Colors.green,
        'description': 'Perfect for beginners starting their fitness journey'
      },
      {
        'steps': 4000,
        'title': 'Walker',
        'icon': Icons.hiking,
        'color': Colors.blue,
        'description': 'Regular walking routine for gradual improvement'
      },
      {
        'steps': 6000,
        'title': 'Mover',
        'icon': Icons.directions_run,
        'color': Colors.orange,
        'description': 'Active lifestyle with consistent daily movement'
      },
      {
        'steps': 8000,
        'title': 'Athlete',
        'icon': Icons.fitness_center,
        'color': Colors.purple,
        'description': 'Challenging goal for fitness enthusiasts'
      },
      {
        'steps': 10000,
        'title': 'Champion',
        'icon': Icons.emoji_events,
        'color': Colors.amber,
        'description': 'Top-tier goal recommended by fitness experts'
      },
      {
        'steps': 12000,
        'title': 'Warrior',
        'icon': Icons.whatshot,
        'color': Colors.red,
        'description': 'Elite level for maximum health benefits'
      },
    ];

    // Find the closest achievement level
    Map<String, dynamic> currentAchievement = achievementLevels.firstWhere(
      (level) => level['steps'] >= dailyLimit,
      orElse: () => achievementLevels.last,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final dialogHeight =
            screenSize.height * 0.7; // Limit height to 70% of screen
        final dialogWidth =
            screenSize.width > 500 ? 500.0 : screenSize.width * 0.9;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Calculate the closest achievement based on slider value
            int sliderSteps = (sliderValue * 1000).round();
            sliderSteps =
                (sliderSteps / 1000).round() * 1000; // Round to nearest 1000
            if (sliderSteps < 2000) sliderSteps = 2000;
            if (sliderSteps > 12000) sliderSteps = 12000;

            Map<String, dynamic> selectedAchievement =
                achievementLevels.firstWhere(
              (level) => level['steps'] >= sliderSteps,
              orElse: () => achievementLevels.last,
            );

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: dialogHeight,
                  maxWidth: 500,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      TColor.primary.withOpacity(0.9),
                      TColor.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: TColor.primary.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Stack(
                    children: [
                      // Background decoration
                      Positioned(
                        right: -20,
                        top: -20,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -30,
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white.withOpacity(0.05),
                        ),
                      ),

                      // Content
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    "DAILY STEPS QUEST",
                                    style: TextStyle(
                                      fontSize:
                                          screenSize.width < 360 ? 18 : 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon:
                                      Icon(Icons.close, color: Colors.white70),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),

                            SizedBox(height: 10),

                            // Current achievement badge
                            Container(
                              height: screenSize.width < 360 ? 100 : 120,
                              width: screenSize.width < 360 ? 100 : 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    selectedAchievement['color']
                                        .withOpacity(0.7),
                                    selectedAchievement['color'],
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: selectedAchievement['color']
                                        .withOpacity(0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    selectedAchievement['icon'],
                                    color: Colors.white,
                                    size: screenSize.width < 360 ? 40 : 50,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    selectedAchievement['title'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          screenSize.width < 360 ? 14 : 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 15),

                            // Selected steps display
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions_run,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "${sliderSteps.toStringAsFixed(0)} Steps",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize:
                                              screenSize.width < 360 ? 18 : 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 15),

                            // Achievement description
                            Container(
                              padding: EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                selectedAchievement['description'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenSize.width < 360 ? 12 : 14,
                                  height: 1.3,
                                ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // Slider with achievement markers
                            Container(
                              height: 50,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      // Achievement markers
                                      ...achievementLevels.map((achievement) {
                                        double position =
                                            (achievement['steps'] / 12000) *
                                                constraints.maxWidth;

                                        // Ensure marker positions don't overflow
                                        position = position.clamp(
                                            0.0, constraints.maxWidth - 2);

                                        return Positioned(
                                          left: position,
                                          top: 0,
                                          child: Container(
                                            height: 25,
                                            width: 2,
                                            color: achievement['steps'] <=
                                                    sliderSteps
                                                ? Colors.white
                                                : Colors.white30,
                                          ),
                                        );
                                      }).toList(),

                                      // Labels for min and max
                                      Positioned(
                                        left: 0,
                                        bottom: 0,
                                        child: Text(
                                          "2K",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Text(
                                          "12K",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),

                                      // Slider itself
                                      SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 8,
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor:
                                              Colors.white.withOpacity(0.3),
                                          thumbColor:
                                              selectedAchievement['color'],
                                          thumbShape: RoundSliderThumbShape(
                                            enabledThumbRadius: 12,
                                            elevation: 4,
                                          ),
                                          overlayColor:
                                              selectedAchievement['color']
                                                  .withOpacity(0.2),
                                          overlayShape: RoundSliderOverlayShape(
                                              overlayRadius: 20),
                                        ),
                                        child: Slider(
                                          min: 2,
                                          max: 12,
                                          divisions: 10,
                                          value: sliderValue,
                                          onChanged: (value) {
                                            setDialogState(() {
                                              sliderValue = value;
                                              selectedLimit =
                                                  (value * 1000).round();
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            SizedBox(height: 15),

                            // Achievement level indicators - Scrollable on small screens
                            Container(
                              height: 70,
                              child: Scrollbar(
                                thumbVisibility: true,
                                thickness: 2,
                                radius: Radius.circular(10),
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children:
                                      achievementLevels.map((achievement) {
                                    bool isUnlocked =
                                        achievement['steps'] <= sliderSteps;
                                    bool isSelected =
                                        achievement['steps'] == sliderSteps;

                                    return Container(
                                      width: screenSize.width < 360 ? 50 : 60,
                                      margin:
                                          EdgeInsets.symmetric(horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? achievement['color']
                                                .withOpacity(0.7)
                                            : (isUnlocked
                                                ? Colors.white.withOpacity(0.2)
                                                : Colors.white
                                                    .withOpacity(0.05)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isUnlocked
                                                ? achievement['icon']
                                                : Icons.lock,
                                            color: isUnlocked
                                                ? Colors.white
                                                : Colors.white30,
                                            size: screenSize.width < 360
                                                ? 20
                                                : 24,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "${(achievement['steps'] / 1000).toStringAsFixed(0)}K",
                                            style: TextStyle(
                                              color: isUnlocked
                                                  ? Colors.white
                                                  : Colors.white30,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Set Goal Button
                                GestureDetector(
                                  onTap: () {
                                    int goalValue =
                                        (sliderValue * 1000).round();
                                    goalValue = (goalValue / 1000).round() *
                                        1000; // Round to nearest 1000
                                    if (goalValue < 2000) goalValue = 2000;
                                    if (goalValue > 12000) goalValue = 12000;

                                    setState(() {
                                      dailyLimit = goalValue;
                                      // Save the new goal
                                      if (userId != null) {
                                        final today = DateTime.now();
                                        _saveStepData(today, currentSteps);
                                      }
                                    });

                                    // Save the new goal immediately to ensure persistence
                                    if (userId != null) {
                                      _firestore
                                          .collection('users')
                                          .doc(userId)
                                          .update({
                                        'currentStepGoal': goalValue,
                                      }).then((_) {
                                        print(
                                            'Updated persistent step goal to $goalValue');
                                        // Also update today's record
                                        final today = DateTime.now();
                                        _saveStepData(today, currentSteps);
                                      }).catchError((e) {
                                        print(
                                            'Error updating persistent step goal: $e');
                                      });
                                    }

                                    // Show success animation
                                    Navigator.of(context).pop();

                                    // Show a gamified success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor:
                                            selectedAchievement['color'],
                                        duration: Duration(seconds: 3),
                                        content: Row(
                                          children: [
                                            Icon(Icons.emoji_events,
                                                color: Colors.white),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "New Quest Accepted!",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    "Complete ${dailyLimit} steps to earn the ${selectedAchievement['title']} badge",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal:
                                            screenSize.width < 360 ? 25 : 40,
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          selectedAchievement['color']
                                              .withOpacity(0.8),
                                          selectedAchievement['color'],
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: selectedAchievement['color']
                                              .withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flag, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          "ACCEPT QUEST",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: screenSize.width < 360
                                                ? 14
                                                : 16,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void updateWeight(double newWeight) {
    setState(() {
      userWeight = newWeight;
    });
  }

  void updateHeight(double newHeight) {
    setState(() {
      userHeight = newHeight;
    });
  }

  void calculateWaterGoal() {
    if (userWeight > 0) {
      dailyWaterGoal = (userWeight * 33);
    }
  }

  void addWaterIntake(double amount) {
    setState(() {
      double previousIntake = currentWaterIntake;
      currentWaterIntake = min(currentWaterIntake + amount, dailyWaterGoal);
      _updateWaterIntakeInDatabase();

      if (previousIntake < dailyWaterGoal &&
          currentWaterIntake >= dailyWaterGoal) {}
    });
  }

  Future<void> _updateWaterIntakeInDatabase() async {
    try {
      await _firestore.collection('user_profiles').doc(widget.username).update({
        'waterIntake': currentWaterIntake,
        'lastWaterUpdate': DateTime.now(),
      });
    } catch (e) {
      print('Error updating water intake: $e');
    }
  }

  void resetWaterIntake() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Reset Water Intake",
            style: TextStyle(
              color: TColor.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
              "Are you sure you want to reset your water intake for today?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  currentWaterIntake = 0;
                  _updateWaterIntakeInDatabase();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Water intake reset successfully'),
                    backgroundColor: TColor.primary,
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: TColor.primary,
              ),
              child: Text(
                "Reset",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  String getMuscleRank(int level) {
    if (level >= 100) return 'Master';
    if (level >= 80) return 'Expert';
    if (level >= 60) return 'Advanced';
    if (level >= 40) return 'Intermediate';
    if (level >= 20) return 'Novice';
    return 'Beginner';
  }

  double calculateLevelProgress(String rank, int level) {
    var requirement = rankRequirements[rank];
    if (requirement == null) return 0.0;

    int maxLevel = requirement['maxLevel'] as int;
    int previousMaxLevel = getPreviousMaxLevel(rank);
    int levelsInRank = maxLevel - previousMaxLevel;

    if (levelsInRank == 0) return 0.0;

    double progress = (level - previousMaxLevel) / levelsInRank;
    return progress.clamp(0.0, 1.0);
  }

  int getPreviousMaxLevel(String rank) {
    switch (rank) {
      case 'Novice':
        return 10;
      case 'Intermediate':
        return 20;
      case 'Advanced':
        return 40;
      case 'Expert':
        return 60;
      case 'Master':
        return 80;
      default:
        return 0;
    }
  }

  Color getRankColor(String rank) {
    switch (rank.toLowerCase()) {
      case 'beginner':
        return Color(0xFF8E8E8E);
      case 'novice':
        return Color(0xFFCD7F32);
      case 'intermediate':
        return Color(0xFF4682B4);
      case 'advanced':
        return Color(0xFFFFD700);
      case 'expert':
        return Color(0xFF800080);
      case 'master':
        return Color(0xFFFF4500);
      default:
        return Color(0xFF8E8E8E);
    }
  }

  Widget _buildStatsProgressBar(String muscle) {
    double progress = 0.0;
    int level = 1;

    if (muscleStats.containsKey(muscle)) {
      var muscleData = muscleStats[muscle]!;
      if (muscleData.containsKey('progress') &&
          muscleData.containsKey('level')) {
        var progressValue = muscleData['progress'];
        var levelValue = muscleData['level'];

        if (progressValue is num) {
          progress = progressValue.toDouble();
        }

        if (levelValue is num) {
          level = levelValue.toInt();
        }
      }
    }

    String rank = getMuscleRank(level);
    Color rankColor = getRankColor(rank);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Muscle name with rank color
              Expanded(
                child: Text(
                  muscle.capitalize(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        rankColor, // Changed from TColor.primary to rankColor
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Level indicator
              Text(
                "Lvl $level",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: rankColor,
                ),
              ),
            ],
          ),
        ),
        // Progress bar
        Container(
          margin: EdgeInsets.only(bottom: 8),
          child: LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                // Background
                Container(
                  height: 5,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.5),
                    color: Colors.grey[200],
                  ),
                ),
                // Progress fill
                Container(
                  height: 5,
                  width: constraints.maxWidth * progress,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.5),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        rankColor.withOpacity(0.6),
                        rankColor,
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // Add method to load water intake history
  Future<void> _loadWaterIntakeHistory() async {
    try {
      if (widget.username.isEmpty) {
        print('Username is empty, cannot load water intake history');
        return;
      }

      print('Loading water intake history for user: ${widget.username}');

      // Get data for at least the current week plus additional days
      final today = DateTime.now();
      final monday = today.subtract(Duration(days: today.weekday - 1));

      final historySnapshot = await _firestore
          .collection('user_profiles')
          .doc(widget.username)
          .collection('water_intake_history')
          .where('date',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(monday.subtract(Duration(days: 7))))
          .orderBy('date', descending: true)
          .limit(21) // Get up to 3 weeks of data
          .get();

      if (historySnapshot.docs.isEmpty) {
        print('No water intake history documents found');
      } else {
        print(
            'Found ${historySnapshot.docs.length} water intake history documents');
      }

      List<Map<String, dynamic>> history = [];

      for (var doc in historySnapshot.docs) {
        try {
          var data = doc.data();
          if (data.containsKey('amount') && data.containsKey('date')) {
            history.add({
              'date': data['date'],
              'amount': (data['amount'] is num)
                  ? (data['amount'] as num).toDouble()
                  : 0.0,
            });
          }
        } catch (e) {
          print('Error parsing water intake document: $e');
        }
      }

      if (mounted) {
        setState(() {
          waterIntakeHistory = history;
        });
      }

      print(
          'Water intake history loaded: ${waterIntakeHistory.length} entries');

      // If there's no history, let's create a sample entry for today
      if (waterIntakeHistory.isEmpty && currentWaterIntake > 0) {
        _saveDailyWaterIntake(currentWaterIntake, DateTime.now());
      }
    } catch (e) {
      print('Error loading water intake history: $e');
    }
  }

  // Add method to save daily water intake to history when day changes
  Future<void> _saveDailyWaterIntake(double amount, DateTime date) async {
    if (amount <= 0) return; // Don't save zero amounts

    try {
      print('Saving water intake: $amount ml for date: $date');
      // Use a document ID based on the date to avoid duplicates
      final String docId = DateFormat('yyyyMMdd').format(date);

      await _firestore
          .collection('user_profiles')
          .doc(widget.username)
          .collection('water_intake_history')
          .doc(docId)
          .set({
        'amount': amount,
        'date': Timestamp.fromDate(date),
      });

      print('Water intake saved successfully');

      // Add the entry to local state immediately
      setState(() {
        // Check if this date already exists in the history
        int existingIndex = waterIntakeHistory.indexWhere((entry) {
          Timestamp timestamp = entry['date'];
          return DateUtils.isSameDay(timestamp.toDate(), date);
        });

        if (existingIndex >= 0) {
          // Update existing entry
          waterIntakeHistory[existingIndex] = {
            'date': Timestamp.fromDate(date),
            'amount': amount,
          };
        } else {
          // Add new entry
          waterIntakeHistory.add({
            'date': Timestamp.fromDate(date),
            'amount': amount,
          });
          // Sort by date descending
          waterIntakeHistory.sort((a, b) {
            Timestamp aDate = a['date'];
            Timestamp bDate = b['date'];
            return bDate.compareTo(aDate);
          });
        }
      });
    } catch (e) {
      print('Error saving water intake history: $e');
    }
  }

  // Add method to show water intake history dialog
  void _showWaterIntakeHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          // Make the dialog bigger and more spacious
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7, // Make it taller
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Water Intake History",
                      style: TextStyle(
                        fontSize: 20, // Increased font size
                        fontWeight: FontWeight.bold,
                        color: TColor.primary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Expanded(
                  child: waterIntakeHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.water_drop_outlined,
                                  size: 48,
                                  color: Colors.grey.withOpacity(0.5)),
                              SizedBox(height: 16),
                              Text(
                                "No recent history available",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Your water intake history will appear here",
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Summary section
                            Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 15),
                              decoration: BoxDecoration(
                                color: TColor.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: TColor.primary.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Daily Goal",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        "${dailyWaterGoal.toInt()}ml",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: TColor.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Average (Last 7 Days)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        "${_calculateAverageWaterIntake().toInt()}ml",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: TColor.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 15),

                            // Chart section with title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 4, bottom: 6),
                                  child: Text(
                                    "Weekly Overview",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: TColor.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 150, // Increased height for the chart
                                  child: _buildWaterIntakeChart(),
                                ),
                              ],
                            ),
                            SizedBox(height: 15),

                            // List section with title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        EdgeInsets.only(left: 4, bottom: 6),
                                    child: Text(
                                      "Daily Records",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: TColor.primary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    // Added indicator to scrollable section
                                    child: RawScrollbar(
                                      thumbColor:
                                          TColor.primary.withOpacity(0.7),
                                      radius: Radius.circular(10),
                                      thickness: 5,
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        itemCount: waterIntakeHistory.length,
                                        itemBuilder: (context, index) {
                                          final entry =
                                              waterIntakeHistory[index];
                                          final date = entry['date'].toDate();
                                          final amount =
                                              entry['amount'] as double;
                                          final percentComplete =
                                              (amount / dailyWaterGoal * 100)
                                                  .toInt();
                                          final isToday = DateUtils.isSameDay(
                                              date, DateTime.now());

                                          return Container(
                                            margin: EdgeInsets.only(bottom: 10),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical:
                                                    12), // Increased vertical padding
                                            decoration: BoxDecoration(
                                              color: isToday
                                                  ? TColor.primary
                                                      .withOpacity(0.05)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: isToday
                                                  ? Border.all(
                                                      color: TColor.primary
                                                          .withOpacity(0.2),
                                                      width: 1,
                                                    )
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: TColor.primary
                                                            .withOpacity(0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.water_drop,
                                                        color: TColor.primary,
                                                        size:
                                                            16, // Slightly increased icon size
                                                      ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          DateFormat(
                                                                  'EEE, MMM d')
                                                              .format(date),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isToday
                                                                ? TColor.primary
                                                                : Colors
                                                                    .black87,
                                                          ),
                                                        ),
                                                        Text(
                                                          isToday
                                                              ? "Today"
                                                              : DateFormat(
                                                                      'yyyy')
                                                                  .format(date),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 100,
                                                          height: 8,
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                            color: Colors.grey
                                                                .withOpacity(
                                                                    0.2),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 100 *
                                                                    (amount /
                                                                            dailyWaterGoal)
                                                                        .clamp(
                                                                            0.0,
                                                                            1.0),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                  gradient:
                                                                      LinearGradient(
                                                                    colors: [
                                                                      TColor
                                                                          .primary
                                                                          .withOpacity(
                                                                              0.7),
                                                                      TColor
                                                                          .primary,
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      "${amount.toInt()}ml (${percentComplete}%)",
                                                      style: TextStyle(
                                                        color:
                                                            percentComplete >=
                                                                    100
                                                                ? Colors.green
                                                                : TColor
                                                                    .primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to calculate average water intake from history
  double _calculateAverageWaterIntake() {
    final weekData = _prepareWeeklyWaterData();
    if (weekData.isEmpty) {
      print('No water intake history available for average calculation');
      return 0;
    }

    try {
      // Count only days with data
      double total = 0;
      int daysWithData = 0;

      for (var entry in weekData) {
        double amount = (entry['amount'] is num)
            ? (entry['amount'] as num).toDouble()
            : 0.0;
        if (amount > 0) {
          total += amount;
          daysWithData++;
        }
      }

      if (daysWithData == 0) return 0;
      return total / daysWithData;
    } catch (e) {
      print('Error calculating average water intake: $e');
      return 0;
    }
  }

  // Add method to build water intake chart
  Widget _buildWaterIntakeChart() {
    if (waterIntakeHistory.isEmpty && currentWaterIntake == 0) {
      print('No water intake history available for chart');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined,
                size: 32, color: Colors.grey.withOpacity(0.5)),
            SizedBox(height: 8),
            Text(
              "No data available",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 4),
            Text(
              "Add water to see your progress",
              style: TextStyle(
                color: Colors.grey.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    // Prepare data for the current week
    final weekData = _prepareWeeklyWaterData();

    return Column(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(weekData.length, (index) {
                final entry = weekData[index];
                final date = (entry['date'] as Timestamp).toDate();
                final amount = entry['amount'] as double;
                final percent = (amount / dailyWaterGoal).clamp(0.0, 1.0);
                final barHeight = 90 * percent;

                bool isToday = DateUtils.isSameDay(date, DateTime.now());
                bool goalReached = amount >= dailyWaterGoal;

                // Get weekday name (Mon, Tue, etc.)
                final weekdayName = DateFormat('E').format(date);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: barHeight > 0
                          ? barHeight
                          : 2, // Minimum height for visibility
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: goalReached
                              ? [Colors.green.withOpacity(0.7), Colors.green]
                              : isToday
                                  ? [
                                      TColor.primary.withOpacity(0.7),
                                      TColor.primary
                                    ]
                                  : [
                                      TColor.primary.withOpacity(0.3),
                                      TColor.primary.withOpacity(0.6)
                                    ],
                        ),
                        boxShadow: isToday && barHeight > 4
                            ? [
                                BoxShadow(
                                  color: TColor.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: goalReached
                          ? Center(
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(height: 5),
                    Text(
                      weekdayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? TColor.primary : Colors.grey,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        // Chart labels
        Container(
          padding: EdgeInsets.only(top: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "0ml",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
              Text(
                "${dailyWaterGoal.toInt()}ml",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add this method to load step history
  Future<void> _loadStepHistory() async {
    if (userId == null) {
      print('Cannot load step history: userId is null');
      return;
    }

    try {
      print('Loading step history...');
      // Get data for at least the current week plus additional days
      final today = DateTime.now();
      final monday = today.subtract(Duration(days: today.weekday - 1));

      final historySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('steps')
          .where('date',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(monday.subtract(Duration(days: 7))))
          .orderBy('date', descending: true)
          .limit(21) // Get up to 3 weeks of data
          .get();

      List<Map<String, dynamic>> history = [];

      for (var doc in historySnapshot.docs) {
        try {
          var data = doc.data();
          history.add({
            'date': data['date'],
            'steps': data['steps'] as int? ?? 0,
            'goal': data['goal'] as int? ?? dailyLimit,
          });
        } catch (e) {
          print('Error processing step history document: $e');
        }
      }

      print('Loaded ${history.length} step history entries');

      setState(() {
        stepHistory = history;
      });
    } catch (e) {
      print('Error loading step history: $e');
    }
  }

  // Add method to show step history dialog
  void _showStepHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          // Make the dialog bigger and more spacious
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7, // Make it taller
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Step History",
                      style: TextStyle(
                        fontSize: 20, // Increased font size
                        fontWeight: FontWeight.bold,
                        color: TColor.primary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Expanded(
                  child: stepHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_walk_outlined,
                                  size: 48,
                                  color: Colors.grey.withOpacity(0.5)),
                              SizedBox(height: 16),
                              Text(
                                "No recent history available",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Your step history will appear here",
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Summary section
                            Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 15),
                              decoration: BoxDecoration(
                                color: TColor.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: TColor.primary.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Daily Goal",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        "${dailyLimit} steps",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: TColor.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Average (Last 7 Days)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        "${_calculateAverageSteps().toInt()} steps",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: TColor.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 15),

                            // Chart section with title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 4, bottom: 6),
                                  child: Text(
                                    "Weekly Overview",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: TColor.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 150, // Increased height for the chart
                                  child: _buildStepHistoryChart(),
                                ),
                              ],
                            ),
                            SizedBox(height: 15),

                            // List section with title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        EdgeInsets.only(left: 4, bottom: 6),
                                    child: Text(
                                      "Daily Records",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: TColor.primary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    // Added indicator to scrollable section
                                    child: RawScrollbar(
                                      thumbColor:
                                          TColor.primary.withOpacity(0.7),
                                      radius: Radius.circular(10),
                                      thickness: 5,
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        itemCount: stepHistory.length,
                                        itemBuilder: (context, index) {
                                          final entry = stepHistory[index];
                                          final date = entry['date'].toDate();
                                          final steps = entry['steps'] as int;
                                          final goal = entry['goal'] as int;
                                          final percentComplete =
                                              (steps / goal * 100).toInt();
                                          final isToday = DateUtils.isSameDay(
                                              date, DateTime.now());

                                          return Container(
                                            margin: EdgeInsets.only(bottom: 10),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isToday
                                                  ? TColor.primary
                                                      .withOpacity(0.05)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: isToday
                                                  ? Border.all(
                                                      color: TColor.primary
                                                          .withOpacity(0.2),
                                                      width: 1,
                                                    )
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: TColor.primary
                                                            .withOpacity(0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.directions_walk,
                                                        color: TColor.primary,
                                                        size: 16,
                                                      ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          DateFormat(
                                                                  'EEE, MMM d')
                                                              .format(date),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isToday
                                                                ? TColor.primary
                                                                : Colors
                                                                    .black87,
                                                          ),
                                                        ),
                                                        Text(
                                                          isToday
                                                              ? "Today"
                                                              : DateFormat(
                                                                      'yyyy')
                                                                  .format(date),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 100,
                                                          height: 8,
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                            color: Colors.grey
                                                                .withOpacity(
                                                                    0.2),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 100 *
                                                                    (steps /
                                                                            goal)
                                                                        .clamp(
                                                                            0.0,
                                                                            1.0),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                  gradient:
                                                                      LinearGradient(
                                                                    colors: [
                                                                      TColor
                                                                          .primary
                                                                          .withOpacity(
                                                                              0.7),
                                                                      TColor
                                                                          .primary,
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      "${steps.toInt()} steps (${percentComplete}%)",
                                                      style: TextStyle(
                                                        color:
                                                            percentComplete >=
                                                                    100
                                                                ? Colors.green
                                                                : TColor
                                                                    .primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to calculate average steps from history
  double _calculateAverageSteps() {
    final weekData = _prepareWeeklyStepData();
    if (weekData.isEmpty) return 0;

    // Count only days with data
    int total = 0;
    int daysWithData = 0;

    for (var entry in weekData) {
      int steps = entry['steps'] as int;
      if (steps > 0) {
        total += steps;
        daysWithData++;
      }
    }

    if (daysWithData == 0) return 0;
    return total / daysWithData;
  }

  // Add method to build step history chart
  Widget _buildStepHistoryChart() {
    if (stepHistory.isEmpty && currentSteps == 0) {
      return Center(
        child: Text(
          "No data available",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Prepare data for the current week
    final weekData = _prepareWeeklyStepData();

    return Column(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(weekData.length, (index) {
                final entry = weekData[index];
                final date = (entry['date'] as Timestamp).toDate();
                final steps = entry['steps'] as int;
                final goal = entry['goal'] as int;
                final percent = (steps / goal).clamp(0.0, 1.0);
                final barHeight = 90 * percent;

                bool isToday = DateUtils.isSameDay(date, DateTime.now());
                bool goalReached = steps >= goal;

                // Get weekday name (Mon, Tue, etc.)
                final weekdayName = DateFormat('E').format(date);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: barHeight > 0
                          ? barHeight
                          : 2, // Minimum height for visibility
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: goalReached
                              ? [Colors.green.withOpacity(0.7), Colors.green]
                              : isToday
                                  ? [
                                      TColor.primary.withOpacity(0.7),
                                      TColor.primary
                                    ]
                                  : [
                                      TColor.primary.withOpacity(0.3),
                                      TColor.primary.withOpacity(0.6)
                                    ],
                        ),
                        boxShadow: isToday && barHeight > 4
                            ? [
                                BoxShadow(
                                  color: TColor.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: goalReached
                          ? Center(
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(height: 5),
                    Text(
                      weekdayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? TColor.primary : Colors.grey,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        // Chart labels
        Container(
          padding: EdgeInsets.only(top: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "0 steps",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
              Text(
                "$dailyLimit steps",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add this helper method to get the current week's dates (Monday to Sunday)
  List<DateTime> _getCurrentWeekDates() {
    final now = DateTime.now();

    // Find the most recent Monday (or today if it's Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // Create a list of dates for this week (Monday to Sunday)
    return List.generate(
        7, (index) => DateTime(monday.year, monday.month, monday.day + index));
  }

  // Method to prepare water intake data for current week
  List<Map<String, dynamic>> _prepareWeeklyWaterData() {
    final weekDates = _getCurrentWeekDates();

    // Create default entries for each day of the week with 0 intake
    final weekData = weekDates.map((date) {
      return {
        'date': Timestamp.fromDate(date),
        'amount': 0.0,
      };
    }).toList();

    // Fill in actual data where available
    for (var entry in waterIntakeHistory) {
      final entryDate = (entry['date'] as Timestamp).toDate();

      for (int i = 0; i < weekDates.length; i++) {
        if (DateUtils.isSameDay(entryDate, weekDates[i])) {
          weekData[i] = entry.cast<String, Object>();
          break;
        }
      }
    }

    // Add today's data if it's not in history yet
    if (currentWaterIntake > 0) {
      final now = DateTime.now();
      bool todayFound = false;

      for (int i = 0; i < weekData.length; i++) {
        final date = (weekData[i]['date'] as Timestamp).toDate();
        if (DateUtils.isSameDay(now, date)) {
          if ((weekData[i]['amount'] as double) < currentWaterIntake) {
            weekData[i] = {
              'date': Timestamp.fromDate(now),
              'amount': currentWaterIntake,
            };
          }
          todayFound = true;
          break;
        }
      }
    }

    return weekData;
  }

  // Method to prepare step history data for current week
  List<Map<String, dynamic>> _prepareWeeklyStepData() {
    final weekDates = _getCurrentWeekDates();

    // Create default entries for each day of the week with 0 steps
    final weekData = weekDates.map((date) {
      return {
        'date': Timestamp.fromDate(date),
        'steps': 0,
        'goal': dailyLimit,
      };
    }).toList();

    // Fill in actual data where available
    for (var entry in stepHistory) {
      final entryDate = (entry['date'] as Timestamp).toDate();

      for (int i = 0; i < weekDates.length; i++) {
        if (DateUtils.isSameDay(entryDate, weekDates[i])) {
          weekData[i] = entry.cast<String, Object>();
          break;
        }
      }
    }

    // Add today's data if it's not in history yet
    if (currentSteps > 0) {
      final now = DateTime.now();
      bool todayFound = false;

      for (int i = 0; i < weekData.length; i++) {
        final date = (weekData[i]['date'] as Timestamp).toDate();
        if (DateUtils.isSameDay(now, date)) {
          if ((weekData[i]['steps'] as int) < currentSteps) {
            weekData[i] = {
              'date': Timestamp.fromDate(now),
              'steps': currentSteps,
              'goal': dailyLimit,
            };
          }
          todayFound = true;
          break;
        }
      }
    }

    return weekData;
  }

  // Display unified exercise history for all pose estimation exercises
  void _showExerciseHistoryDialog() {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load history. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Exercise History",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TColor.primary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('pose_exercise_history')
                        .where('userId', isEqualTo: userId)
                        .orderBy('date', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading history: ${snapshot.error}',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_outlined,
                                size: 48,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No exercise history yet",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Complete exercises to see your progress",
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      // Group exercises by date for better organization
                      Map<String, List<DocumentSnapshot>> groupedExercises = {};

                      for (var doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final date = data['date'] as Timestamp?;

                        if (date != null) {
                          final dateStr =
                              DateFormat('yyyy-MM-dd').format(date.toDate());

                          if (!groupedExercises.containsKey(dateStr)) {
                            groupedExercises[dateStr] = [];
                          }

                          groupedExercises[dateStr]!.add(doc);
                        }
                      }

                      // Sort dates in descending order
                      final sortedDates = groupedExercises.keys.toList()
                        ..sort((a, b) => b.compareTo(a));

                      return ListView.builder(
                        itemCount: sortedDates.length,
                        itemBuilder: (context, index) {
                          final dateStr = sortedDates[index];
                          final exercisesForDate = groupedExercises[dateStr]!;
                          final formattedDate = DateFormat('EEEE, MMMM d, yyyy')
                              .format(DateTime.parse(dateStr));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: TColor.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: TColor.primary,
                                    ),
                                  ),
                                ),
                              ),
                              ...exercisesForDate.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final exerciseName =
                                    data['exerciseName'] as String;
                                final targetSets =
                                    data['targetSets'] as int? ?? 0;
                                final targetReps =
                                    data['targetReps'] as int? ?? 0;
                                final completedSets =
                                    data['completedSets'] as int? ?? 0;
                                final completedReps =
                                    data['completedReps'] as int? ?? 0;
                                final timeStamp = data['date'] as Timestamp?;
                                final completion = data['completion'] as int? ??
                                    (targetSets > 0
                                        ? (completedSets / targetSets * 100)
                                            .round()
                                        : 0);

                                // Get time of day
                                final timeStr = timeStamp != null
                                    ? DateFormat('h:mm a')
                                        .format(timeStamp.toDate())
                                    : "Unknown time";

                                // Get appropriate icon for exercise type
                                IconData exerciseIcon;
                                switch (exerciseName) {
                                  case 'Push Ups':
                                    exerciseIcon = Icons.fitness_center;
                                    break;
                                  case 'Pull Ups':
                                    exerciseIcon = Icons.fitness_center;
                                    break;
                                  case 'Squat':
                                    exerciseIcon = Icons.accessibility_new;
                                    break;
                                  case 'Sit Ups':
                                    exerciseIcon = Icons.accessibility_new;
                                    break;
                                  case 'Jumping Jacks':
                                    exerciseIcon = Icons.directions_run;
                                    break;
                                  default:
                                    exerciseIcon = Icons.sports_gymnastics;
                                }

                                // Get color based on completion percentage
                                Color progressColor;
                                if (completion >= 100) {
                                  progressColor = Colors.green;
                                } else if (completion >= 75) {
                                  progressColor = Colors.orange;
                                } else if (completion >= 50) {
                                  progressColor = Colors.amber;
                                } else {
                                  progressColor = Colors.red;
                                }

                                return Container(
                                  margin: EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: TColor.primary.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        leading: Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color:
                                                TColor.primary.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            exerciseIcon,
                                            color: TColor.primary,
                                            size: 24,
                                          ),
                                        ),
                                        title: Text(
                                          exerciseName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        trailing: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color:
                                                progressColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            border: Border.all(
                                              color: progressColor
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                          child: Text(
                                            "$completion%",
                                            style: TextStyle(
                                              color: progressColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Divider(height: 1),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildExerciseHistoryStat(
                                              label: "Sets",
                                              value:
                                                  "$completedSets/$targetSets",
                                              icon: Icons.repeat,
                                            ),
                                            _buildExerciseHistoryStat(
                                              label: "Reps",
                                              value:
                                                  "$completedReps/$targetReps",
                                              icon: Icons.fitness_center,
                                            ),
                                            _buildExerciseHistoryStat(
                                              label: "Rest",
                                              value:
                                                  "${data['restTime'] ?? 0}s",
                                              icon: Icons.timer,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build exercise history stats
  Widget _buildExerciseHistoryStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: TColor.primary,
            ),
            SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // Add a history button in the bottom navigation bar or in an appropriate location
  // Modify the build method to add a history button
  // Find the section of the build method with bottom navigation or toolbar and add:

  // In the appropriate place in your UI, add this button:

  // Add this method to your existing helpers in the home view
  void _showPoseExerciseHistory() {
    _showExerciseHistoryDialog();
  }

  @override
  Widget build(BuildContext context) {
    double progress = currentSteps / dailyLimit;

    int currentDay = DateTime.now().weekday;

    List<String> daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    int currentDayIndex = (currentDay % 7);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: TColor.primary,
        centerTitle: true,
        elevation: 10.0,
        shadowColor: Colors.black.withOpacity(0.5),
        title: Text(
          "GRIT",
          style: TextStyle(
              color: TColor.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                color: TColor.primary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    return Text(
                      daysOfWeek[index],
                      style: TextStyle(
                        color: index == currentDayIndex
                            ? Colors.yellow
                            : TColor.white,
                        fontWeight: index == currentDayIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: Container(
                  color: TColor.white,
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
            ],
          ),
          Stack(
            children: [
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DailyChalView()),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Daily Challenges",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: TColor.primary),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Complete Today's Challenges",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: TColor.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 150,
                left: 20,
                right: 20,
                child: InkWell(
                  onTap: changeDailyLimit,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_walk_rounded,
                                  color: TColor.primary,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Daily Steps",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: TColor.primary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Add history button
                                InkWell(
                                  onTap: _showStepHistory,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: TColor.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: TColor.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.history,
                                          color: TColor.primary,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "History",
                                          style: TextStyle(
                                            color: TColor.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TColor.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: TColor.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        color: TColor.primary,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Streak: $streakCount",
                                        style: TextStyle(
                                          color: TColor.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey[200],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      TColor.primary),
                                  minHeight: 20,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "$currentSteps / $dailyLimit steps",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                        color: Colors.black26,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Update to use the new percentage-based milestone method
                            _buildStepMilestonePercentage(
                                2000, currentSteps, ""),
                            _buildStepMilestonePercentage(
                                4000, currentSteps, ""),
                            _buildStepMilestonePercentage(
                                6000, currentSteps, ""),
                            _buildStepMilestonePercentage(
                                8000, currentSteps, ""),
                            _buildStepMilestonePercentage(
                                10000, currentSteps, ""),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Stack(
            children: [
              Positioned(
                top: 280,
                left: 20,
                right: 20,
                bottom: 80,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        height: 230,
                        margin: EdgeInsets.symmetric(vertical: 10),
                        child: PageView(
                          onPageChanged: (int page) {
                            setState(() {
                              currentPage = page;
                            });
                          },
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: TColor.primary.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                                border: Border.all(
                                  color: TColor.primary.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => TrainingStatsView(
                                        username: widget.username,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "My Stats",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: TColor.primary),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: TColor.primary,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Divider(
                                      color: TColor.primary.withOpacity(0.1),
                                      thickness: 1,
                                      height: 1,
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildStatsProgressBar('chest'),
                                              _buildStatsProgressBar('back'),
                                              _buildStatsProgressBar('arms'),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildStatsProgressBar(
                                                  'abdominals'),
                                              _buildStatsProgressBar('legs'),
                                              _buildStatsProgressBar(
                                                  'shoulders'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Container(
                                      alignment: Alignment.center,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color:
                                              TColor.primary.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color:
                                                TColor.primary.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          "View Full Stats",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: TColor.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WeightView(
                                        onWeightUpdate: updateWeight,
                                        username: widget.username,
                                        initialHeight: userHeight,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.monitor_weight_outlined,
                                                size: 18,
                                                color: TColor.primary,
                                              ),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  "Body Mass Index",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: TColor.primary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.history,
                                            size: 18,
                                            color: TColor.primary,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    WeightView(
                                                  onWeightUpdate: updateWeight,
                                                  username: widget.username,
                                                  initialHeight: 0.0,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: getBMIColor(
                                                              calculateBMI()),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              calculateBMI()
                                                                  .toStringAsFixed(
                                                                      1),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: TColor
                                                                    .primary,
                                                              ),
                                                            ),
                                                            Text(
                                                              'BMI',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    CustomPaint(
                                                      size: Size(90, 90),
                                                      painter: BMIArcPainter(
                                                        progress:
                                                            (calculateBMI() -
                                                                    15) /
                                                                25,
                                                        color: getBMIColor(
                                                            calculateBMI()),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: getBMIColor(
                                                            calculateBMI())
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                      color: getBMIColor(
                                                          calculateBMI()),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    getBMICategory(
                                                        calculateBMI()),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: getBMIColor(
                                                          calculateBMI()),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _buildStatCard(
                                                  icon: Icons.height,
                                                  label: 'Height',
                                                  value:
                                                      '${userHeight.toStringAsFixed(1)} cm',
                                                ),
                                                SizedBox(height: 8),
                                                _buildStatCard(
                                                  icon: Icons.monitor_weight,
                                                  label: 'Weight',
                                                  value:
                                                      '${userWeight.toStringAsFixed(1)} kg',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              padding: EdgeInsets.all(12),
                              height: 230,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.water_drop,
                                              color: TColor.primary, size: 18),
                                          SizedBox(width: 6),
                                          Text(
                                            "Water Intake",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: TColor.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: _showWaterIntakeHistory,
                                            child: Icon(Icons.history,
                                                color: TColor.primary,
                                                size: 18),
                                          ),
                                          SizedBox(width: 15),
                                          InkWell(
                                            onTap: resetWaterIntake,
                                            child: Icon(Icons.refresh_rounded,
                                                color: TColor.primary,
                                                size: 18),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          height: 100,
                                          width: 100,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                TColor.primary.withOpacity(0.1),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "${(currentWaterIntake / dailyWaterGoal * 100).toInt()}%",
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: TColor.primary,
                                                ),
                                              ),
                                              Text(
                                                "${currentWaterIntake.toInt()}/${dailyWaterGoal.toInt()}ml",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: TColor.primary
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        CustomPaint(
                                          size: Size(110, 110),
                                          painter: WaterProgressPainter(
                                            progress: currentWaterIntake /
                                                dailyWaterGoal,
                                            color: TColor.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: waterServings.map((serving) {
                                          return InkWell(
                                            onTap: () {
                                              addWaterIntake(
                                                  serving['amount'].toDouble());
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: TColor.primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(serving['icon'],
                                                      color: TColor.primary,
                                                      size: 16),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "${serving['amount']}",
                                                    style: TextStyle(
                                                      color: TColor.primary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            3,
                            (index) => Container(
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentPage == index
                                    ? TColor.primary
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 220,
                        margin:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              TColor.primary.withOpacity(0.05),
                              Colors.white,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: TColor.primary.withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: TColor.primary.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              child: Text(
                                "Recommended Exercises",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: TColor.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: FutureBuilder(
                                future: DefaultAssetBundle.of(context)
                                    .loadString('assets/json/exercises.json'),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    List<dynamic> allExercises =
                                        json.decode(snapshot.data!);

                                    List<dynamic> levelExercises =
                                        allExercises.where((exercise) {
                                      return exercise['level']
                                              .toString()
                                              .toLowerCase() ==
                                          userFitnessLevel;
                                    }).toList();

                                    levelExercises.shuffle();
                                    List<dynamic> randomExercises =
                                        levelExercises.take(5).toList();

                                    return Column(
                                      children: [
                                        Expanded(
                                          child: PageView.builder(
                                            itemCount: randomExercises.length,
                                            onPageChanged: (index) {
                                              setState(() {
                                                currentExerciseIndex = index;
                                              });
                                            },
                                            itemBuilder: (context, index) {
                                              final exercise =
                                                  randomExercises[index];
                                              return Container(
                                                margin: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                height: 140,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: TColor.primary
                                                          .withOpacity(0.1),
                                                      blurRadius: 8,
                                                      spreadRadius: 1,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: InkWell(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ExerciseDetailView(
                                                          exercise: exercise,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Row(
                                                    children: [
                                                      Hero(
                                                        tag:
                                                            'exercise_${exercise['id']}',
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                    12),
                                                            bottomLeft:
                                                                Radius.circular(
                                                                    12),
                                                          ),
                                                          child: Container(
                                                            width: 140,
                                                            height: 140,
                                                            child: Stack(
                                                              children: [
                                                                Image.asset(
                                                                  'assets/json/img/${exercise['images'][0]}',
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  width: 140,
                                                                  height: 140,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.all(8),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                exercise[
                                                                    'name'],
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                  color: TColor
                                                                      .primary,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                exercise[
                                                                        'instructions']
                                                                    .join(' '),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 9,
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  height: 4),
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .star,
                                                                      color: TColor
                                                                          .primary
                                                                          .withOpacity(
                                                                              0.5),
                                                                      size: 14),
                                                                  Text(
                                                                    " ${exercise['level'] ?? 'beginner'}",
                                                                    style:
                                                                        TextStyle(
                                                                      color: TColor
                                                                          .primary,
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: List.generate(
                                              randomExercises.length,
                                              (index) => AnimatedContainer(
                                                duration:
                                                    Duration(milliseconds: 300),
                                                margin: EdgeInsets.symmetric(
                                                    horizontal: 4),
                                                height: 8,
                                                width: currentExerciseIndex ==
                                                        index
                                                    ? 24
                                                    : 8,
                                                decoration: BoxDecoration(
                                                  color: currentExerciseIndex ==
                                                          index
                                                      ? TColor.primary
                                                      : Colors.grey
                                                          .withOpacity(0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return Center(
                                      child: CircularProgressIndicator());
                                },
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ExerciseView(
                                        username: widget.username,
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  backgroundColor:
                                      TColor.primary.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: TColor.primary.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'View More Exercises',
                                  style: TextStyle(
                                    color: TColor.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                BottomAppBar(
                  elevation: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          icon: Icons.leaderboard_rounded,
                          label: "Stats",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TrainingStatsView(
                                  username: widget.username,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.fitness_center_rounded,
                          label: "Exercises",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExerciseView(
                                  username: widget.username,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 60),
                        _buildNavItem(
                          icon: Icons.sports_martial_arts_rounded,
                          label: "Training",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkoutView(
                                  username: widget.username,
                                  userId: userId!,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.settings_rounded,
                          label: "Menu",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MenuView(
                                  username: widget.username,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            TColor.primary.withOpacity(0.8),
                            TColor.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TColor.primary.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: Offset(0, 2),
                          ),
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            spreadRadius: 1,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QuickStartView(),
                              ),
                            );
                          },
                          customBorder: CircleBorder(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 40,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    if (label == "Training") {
      return InkWell(
        onTap: () {
          if (userId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutView(
                  username: widget.username,
                  userId: userId!,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please wait while loading user data')),
            );
          }
        },
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: TColor.primary,
                size: 28,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: TColor.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: TColor.primary,
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: TColor.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: BoxConstraints(maxHeight: 60),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TColor.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TColor.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TColor.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: TColor.primary, size: 18),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value == '0.0 cm' || value == '0.0 kg' ? 'Not set' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: TColor.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepMilestone(int milestone, int currentSteps, String emoji) {
    bool isAchieved = currentSteps >= milestone;
    Color iconColor = isAchieved ? TColor.primary : Colors.grey[400]!;
    IconData icon;

    switch (milestone) {
      case 2000:
        icon = Icons.elderly;
        break;
      case 4000:
        icon = Icons.directions_walk;
        break;
      case 6000:
        icon = Icons.directions_run;
        break;
      case 8000:
        icon = Icons.fitness_center;
        break;
      case 10000:
        icon = Icons.sports_score;
        break;
      default:
        icon = Icons.stars;
    }

    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        SizedBox(height: 4),
        Text(
          "${milestone}",
          style: TextStyle(
            fontSize: 10,
            color: iconColor,
            fontWeight: isAchieved ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // Rename this method from _buildStepMilestone to _buildStepMilestonePercentage
  Widget _buildStepMilestonePercentage(
      int milestone, int currentSteps, String emoji) {
    // Calculate milestones based on percentages of the daily limit
    int milestoneSteps;
    String label;
    IconData icon;

    switch (milestone) {
      case 2000:
        milestoneSteps = (dailyLimit * 0.1).toInt(); // 10%
        icon = Icons.directions_walk;
        label = "10%";
        break;
      case 4000:
        milestoneSteps = (dailyLimit * 0.3).toInt(); // 30%
        icon = Icons.directions_walk;
        label = "30%";
        break;
      case 6000:
        milestoneSteps = (dailyLimit * 0.5).toInt(); // 50%
        icon = Icons.directions_run;
        label = "50%";
        break;
      case 8000:
        milestoneSteps = (dailyLimit * 0.8).toInt(); // 80%
        icon = Icons.fitness_center;
        label = "80%";
        break;
      case 10000:
        milestoneSteps = dailyLimit; // 100%
        icon = Icons.sports_score;
        label = "100%";
        break;
      default:
        milestoneSteps = milestone;
        icon = Icons.stars;
        label = "";
    }

    bool isAchieved = currentSteps >= milestoneSteps;
    Color iconColor = isAchieved ? TColor.primary : Colors.grey[400]!;

    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: iconColor,
            fontWeight: isAchieved ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class BMIArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  BMIArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    );

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.2);

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi,
      false,
      bgPaint,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WaterProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  WaterProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    );

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.2);

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi,
      false,
      bgPaint,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

int currentExerciseIndex = 0;

class StatsProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  StatsProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    print('Painting progress bar: $progress');

    final backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );

    canvas.drawRRect(trackRect, backgroundPaint);

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.5),
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final progressRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
      Radius.circular(size.height / 2),
    );

    canvas.drawRRect(progressRect, progressPaint);

    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height / 2))
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final shineRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width * progress, size.height / 2),
      Radius.circular(size.height / 2),
    );

    canvas.drawRRect(shineRect, shinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
