import 'package:flutter/material.dart';
import '../../common/color_extension.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DailyChalView extends StatefulWidget {
  const DailyChalView({super.key});

  @override
  State<DailyChalView> createState() => _DailyChalViewState();
}

class _DailyChalViewState extends State<DailyChalView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? username;
  String? userId;
  bool _isLoading = true;
  double dailyWaterGoal = 2000; // Default value
  double currentWaterIntake = 0;
  int dailyStepGoal = 10000; // Default value
  int currentSteps = 0;

  List trainingDayArr = [
    {
      "name": "Daily Exercise",
      "description": "Complete 3 exercises from available workouts",
      "target": 3,
      "progress": 0,
      "type": "exercise_count",
    },
    {
      "name": "Water Champion",
      "description": "Finish the recommended daily water intake",
      "target": 1,
      "progress": 0,
      "type": "water_intake",
    },
    {
      "name": "Step Master",
      "description": "Reach your daily step goal",
      "target": 1,
      "progress": 0,
      "type": "steps",
    },
    {
      "name": "Pose Expert",
      "description": "Complete a workout with pose detection",
      "target": 1,
      "progress": 0,
      "type": "pose_detection",
    },
    {
      "name": "Exercise Variety",
      "description": "Try 3 different types of exercises",
      "target": 3,
      "progress": 0,
      "type": "variety",
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUsername().then((_) {
      _loadUserId();
    });
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username');
    });
    print('Daily challenges loaded for username: $username');
  }

  Future<void> _loadUserId() async {
    if (username == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get user ID from username
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final String id = userQuery.docs.first.id;
        print('Found user ID: $id for username: $username');
        setState(() {
          userId = id;
        });
        // Now load challenges data with both username and userId
        _loadDailyChallengesData();
      } else {
        print('User document not found for username: $username');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user ID: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDailyChallengesData() async {
    if (username == null || userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      print('Loading daily challenges data for user ID: $userId');

      // 1. Load water intake data
      await _checkWaterIntakeChallenge();

      // 2. Load exercise completion data
      await _checkExerciseCompletionChallenge();

      // 3. Load steps data
      await _checkStepsChallenge();

      // 4. Load pose detection exercise data
      await _checkPoseDetectionChallenge();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading daily challenges data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkWaterIntakeChallenge() async {
    try {
      // Load user profile to get water goal and current intake
      final userProfileDoc =
          await _firestore.collection('user_profiles').doc(username).get();

      if (userProfileDoc.exists && userProfileDoc.data() != null) {
        final data = userProfileDoc.data()!;

        // Get water intake data
        dailyWaterGoal = (data['waterGoal'] ?? 2000).toDouble();
        currentWaterIntake = (data['waterIntake'] ?? 0).toDouble();

        // Check if water intake goal is met
        bool isWaterGoalMet = currentWaterIntake >= dailyWaterGoal;

        print(
            'Water intake: $currentWaterIntake ml / $dailyWaterGoal ml, Goal met: $isWaterGoalMet');

        setState(() {
          // Update Water Champion challenge
          for (var challenge in trainingDayArr) {
            if (challenge["type"] == "water_intake") {
              challenge["progress"] = isWaterGoalMet ? 1 : 0;
            }
          }
        });
      } else {
        print('User profile document not found for username: $username');
      }
    } catch (e) {
      print('Error checking water intake challenge: $e');
    }
  }

  Future<void> _checkStepsChallenge() async {
    try {
      if (userId == null) return;

      // 1. Get step goal from the user document
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        dailyStepGoal = userData['currentStepGoal'] as int? ?? 10000;
        print('User step goal: $dailyStepGoal');
      }

      // 2. Get today's step count from steps collection
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
        print('Current steps: $currentSteps / $dailyStepGoal');

        // Check if step goal is met
        bool isStepGoalMet = currentSteps >= dailyStepGoal;

        setState(() {
          // Update Step Master challenge
          for (var challenge in trainingDayArr) {
            if (challenge["type"] == "steps") {
              challenge["progress"] = isStepGoalMet ? 1 : 0;
            }
          }
        });
      } else {
        print('No step data found for today');
      }
    } catch (e) {
      print('Error checking steps challenge: $e');
    }
  }

  Future<void> _checkExerciseCompletionChallenge() async {
    try {
      // Get today's date at midnight for comparison
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final Timestamp startOfDayTimestamp = Timestamp.fromDate(startOfDay);

      print('Checking workout history since: ${startOfDay.toString()}');

      // Query workout history for today's workouts
      final QuerySnapshot snapshot = await _firestore
          .collection('workout_history')
          .where('userId', isEqualTo: userId)
          .get();

      print('Retrieved ${snapshot.docs.length} workout history documents');

      // Count the total number of exercises completed today
      int completedExercisesCount = 0;
      Set<String> uniqueExerciseTypes = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Timestamp? dateTimestamp = data['date'] as Timestamp?;

        // Only count exercises from today
        if (dateTimestamp != null) {
          final DateTime docDate = dateTimestamp.toDate();
          final bool isToday = docDate.year == now.year &&
              docDate.month == now.month &&
              docDate.day == now.day;

          print('Document date: ${docDate.toString()}, Is today: $isToday');

          if (isToday && data.containsKey('exercises')) {
            final exercises = data['exercises'] as List<dynamic>;
            print('Found ${exercises.length} exercises in workout');

            if (exercises.isNotEmpty) {
              // Count each completed exercise for the Daily Exercise challenge
              completedExercisesCount += exercises.length;

              // Track unique exercise types for the Exercise Variety challenge
              for (var exercise in exercises) {
                if (exercise is Map<String, dynamic> &&
                    exercise.containsKey('name')) {
                  uniqueExerciseTypes.add(exercise['name'].toString());
                  print(
                      'Added exercise: ${exercise['name']} to unique exercises');
                }
              }
            }
          }
        }
      }

      print('Total exercises completed today: $completedExercisesCount');
      print('Unique exercise types today: ${uniqueExerciseTypes.length}');

      setState(() {
        // Update Daily Exercise challenge
        for (var challenge in trainingDayArr) {
          if (challenge["type"] == "exercise_count") {
            challenge["progress"] =
                completedExercisesCount > challenge["target"]
                    ? challenge["target"]
                    : completedExercisesCount;
            print('Updated exercise_count progress: ${challenge["progress"]}');
          }
          // Update Exercise Variety challenge
          else if (challenge["type"] == "variety") {
            challenge["progress"] =
                uniqueExerciseTypes.length > challenge["target"]
                    ? challenge["target"]
                    : uniqueExerciseTypes.length;
            print('Updated variety progress: ${challenge["progress"]}');
          }
        }
      });
    } catch (e, stackTrace) {
      print('Error checking exercise completion challenge: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _checkPoseDetectionChallenge() async {
    try {
      if (userId == null) return;

      // Get today's date at midnight for comparison
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);

      print(
          'Checking pose detection exercises since: ${startOfDay.toString()}');

      // Query pose_exercise_history for today's activities
      final QuerySnapshot snapshot = await _firestore
          .collection('pose_exercise_history')
          .where('userId', isEqualTo: userId)
          .get();

      print(
          'Retrieved ${snapshot.docs.length} pose detection exercise records');

      // Check if any pose detection exercises were completed today
      bool completedPoseExerciseToday = false;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Timestamp? dateTimestamp = data['timestamp'] as Timestamp?;

        // Only count exercises from today
        if (dateTimestamp != null) {
          final DateTime docDate = dateTimestamp.toDate();
          final bool isToday = docDate.year == now.year &&
              docDate.month == now.month &&
              docDate.day == now.day;

          print('Exercise date: ${docDate.toString()}, Is today: $isToday');

          if (isToday) {
            // Found a pose detection exercise completed today
            completedPoseExerciseToday = true;
            print(
                'Found pose detection exercise completed today: ${data['exerciseName']}');
            break;
          }
        }
      }

      setState(() {
        // Update Pose Expert challenge
        for (var challenge in trainingDayArr) {
          if (challenge["type"] == "pose_detection") {
            challenge["progress"] = completedPoseExerciseToday ? 1 : 0;
            print('Updated pose_detection progress: ${challenge["progress"]}');
          }
        }
      });
    } catch (e) {
      print('Error checking pose detection challenge: $e');
    }
  }

  String getProgressText(Map tObj) {
    if (tObj["type"] == "duration") {
      return "${(tObj["progress"] / 60).floor()}/${(tObj["target"] / 60).floor()} min";
    } else if (tObj["type"] == "steps") {
      return tObj["progress"] >= tObj["target"] ? "Completed" : "Incomplete";
    } else if (tObj["type"] == "nutrition") {
      return "${tObj["progress"]}/${tObj["target"]}g";
    } else if (tObj["type"] == "binary") {
      return tObj["progress"] >= tObj["target"] ? "Completed" : "Incomplete";
    } else if (tObj["type"] == "water_intake") {
      return tObj["progress"] >= tObj["target"] ? "Completed" : "Incomplete";
    } else if (tObj["type"] == "exercise_count" || tObj["type"] == "variety") {
      return "${tObj["progress"]}/${tObj["target"]}";
    }
    return "${tObj["progress"]}/${tObj["target"]} times";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColor.primary,
        centerTitle: true,
        elevation: 0.1,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Image.asset(
            "assets/img/black_white.png",
            width: 25,
            height: 25,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: TColor.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadDailyChallengesData();
            },
          ),
        ],
        title: Text(
          "Daily Challenges",
          style: TextStyle(
              color: TColor.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: TColor.primary),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: trainingDayArr.length,
              itemBuilder: (context, index) {
                var tObj = trainingDayArr[index] as Map? ?? {};
                double progress =
                    (tObj["progress"] / tObj["target"]).clamp(0.0, 1.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: TColor.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tObj["name"].toString(),
                        style: TextStyle(
                            color: TColor.secondaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tObj["description"],
                        style: TextStyle(
                          color: TColor.secondaryText.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      tObj["type"] == "steps"
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      "$currentSteps / $dailyStepGoal",
                                      style: TextStyle(
                                        color: TColor.secondaryText
                                            .withOpacity(0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "steps",
                                      style: TextStyle(
                                        color: TColor.secondaryText
                                            .withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : SizedBox(),
                      const SizedBox(height: 15),
                      LinearPercentIndicator(
                        padding: EdgeInsets.zero,
                        lineHeight: 6,
                        percent: progress,
                        backgroundColor: TColor.primary.withOpacity(0.2),
                        progressColor: TColor.primary,
                        barRadius: const Radius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            getProgressText(tObj),
                            style: TextStyle(
                                color: TColor.secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            "${(progress * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                                color: TColor.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      tObj["progress"] < tObj["target"]
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: TColor.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: TColor.primary.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sync,
                                    color: TColor.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "In Progress",
                                    style: TextStyle(
                                      color: TColor.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 18),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Challenge Completed",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
