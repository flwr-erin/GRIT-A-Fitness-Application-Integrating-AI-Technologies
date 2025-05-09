import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../common/color_extension.dart';
import '../../common/round_button.dart';
import '../services/muscle_progress_service.dart';
import '../services/achievement_service.dart'; // Import achievement service

class ExerciseExecutionView extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final int currentExerciseIndex;
  final String userId;
  final String workoutPlanName;
  final String workoutPlanId;

  const ExerciseExecutionView({
    Key? key,
    required this.exercises,
    required this.currentExerciseIndex,
    required this.userId,
    required this.workoutPlanName,
    required this.workoutPlanId,
  }) : super(key: key);

  @override
  State<ExerciseExecutionView> createState() => _ExerciseExecutionViewState();
}

class _ExerciseExecutionViewState extends State<ExerciseExecutionView> {
  late int currentExerciseIndex;
  late int currentSet;
  int remainingSeconds = 0;
  Timer? timer;
  bool isResting = false;
  bool isWorkoutTransition = false;
  final int workoutTransitionTime = 120; // 2 minutes in seconds

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MuscleProgressService _muscleProgressService = MuscleProgressService();
  final AchievementService _achievementService =
      AchievementService(); // Add achievement service
  final Map<String, dynamic> _workoutStats = {
    'totalSets': 0,
    'totalRestTime': 0,
    'exercises': [],
    'startTime': DateTime.now().millisecondsSinceEpoch,
    'activeTime': 0, // Time spent actively exercising
    'lastExerciseStart': 0, // Timestamp when current exercise began
    'isCurrentlyResting': false,
  };
  bool _saving = false;

  double get timerProgress {
    final exercise = widget.exercises[currentExerciseIndex];
    return 1 - (remainingSeconds / (exercise['restTime'] as int));
  }

  @override
  void initState() {
    super.initState();
    currentExerciseIndex = widget.currentExerciseIndex;
    currentSet = 1;

    // Initialize the first exercise start time
    _workoutStats['lastExerciseStart'] = DateTime.now().millisecondsSinceEpoch;
    _workoutStats['isCurrentlyResting'] = false;
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: TColor.primary,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Exit Workout?',
                  style: TextStyle(
                    color: TColor.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to exit?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your workout progress will be lost.',
                  style: TextStyle(
                    color: TColor.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: TColor.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColor.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Exit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void startRestTimer() {
    final exercise = widget.exercises[currentExerciseIndex];
    final now = DateTime.now().millisecondsSinceEpoch;

    // Calculate and track active exercise time
    if (!_workoutStats['isCurrentlyResting']) {
      _workoutStats['activeTime'] +=
          now - (_workoutStats['lastExerciseStart'] as int);
    }

    // Set resting status
    _workoutStats['isCurrentlyResting'] = true;

    // Track completed set
    _workoutStats['totalSets'] = _workoutStats['totalSets'] + 1;

    // Add the exercise to tracking if not already there
    bool exerciseFound = false;
    for (var ex in _workoutStats['exercises']) {
      if (ex['name'] == exercise['name']) {
        ex['completedSets'] = ex['completedSets'] + 1;
        exerciseFound = true;
        break;
      }
    }

    if (!exerciseFound) {
      _workoutStats['exercises'].add({
        'name': exercise['name'],
        'completedSets': 1,
        'totalSets': exercise['sets'],
        'reps': exercise['reps'],
        'primaryMuscles': exercise['primaryMuscles'] ?? [],
        'secondaryMuscles': exercise['secondaryMuscles'] ?? [],
      });
    }

    setState(() {
      isResting = true;
      remainingSeconds = exercise['restTime'] as int;
    });

    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          isResting = false;
        });

        // Track rest time
        _workoutStats['totalRestTime'] =
            _workoutStats['totalRestTime'] + (exercise['restTime'] as int);

        // Update exercise start time after rest
        _workoutStats['lastExerciseStart'] =
            DateTime.now().millisecondsSinceEpoch;
        _workoutStats['isCurrentlyResting'] = false;

        proceedToNextSetOrExercise();
      }
    });
  }

  void startWorkoutTransitionTimer() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Track active exercise time before transition
    if (!_workoutStats['isCurrentlyResting']) {
      _workoutStats['activeTime'] +=
          now - (_workoutStats['lastExerciseStart'] as int);
    }

    // Set resting status during transition
    _workoutStats['isCurrentlyResting'] = true;

    setState(() {
      isWorkoutTransition = true;
      remainingSeconds = workoutTransitionTime;
    });

    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          isWorkoutTransition = false;
          currentExerciseIndex++;
          currentSet = 1;
        });

        // Track transition time
        _workoutStats['totalRestTime'] =
            _workoutStats['totalRestTime'] + workoutTransitionTime;

        // Reset exercise start time after transition
        _workoutStats['lastExerciseStart'] =
            DateTime.now().millisecondsSinceEpoch;
        _workoutStats['isCurrentlyResting'] = false;
      }
    });
  }

  Widget _buildWorkoutTransitionTimer() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TColor.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rest Before Next Exercise',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: TColor.primary,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Next: ${widget.exercises[currentExerciseIndex + 1]['name']}',
            style: TextStyle(
              fontSize: 18,
              color: TColor.secondaryText,
            ),
          ),
          SizedBox(height: 30),
          CircularPercentIndicator(
            radius: 80,
            lineWidth: 12,
            percent: 1 - (remainingSeconds / workoutTransitionTime),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${remainingSeconds}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: TColor.primary,
                  ),
                ),
                Text(
                  'seconds',
                  style: TextStyle(
                    fontSize: 14,
                    color: TColor.secondaryText,
                  ),
                ),
              ],
            ),
            progressColor: TColor.primary,
            backgroundColor: TColor.primary.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  void proceedToNextSetOrExercise() {
    final exercise = widget.exercises[currentExerciseIndex];
    final totalSets = exercise['sets'] as int;

    if (currentSet < totalSets) {
      setState(() {
        currentSet++;
      });
    } else if (currentExerciseIndex < widget.exercises.length - 1) {
      startWorkoutTransitionTimer();
    } else {
      showWorkoutCompletedDialog();
    }
  }

  Future<void> _saveWorkoutHistory() async {
    if (_saving) return; // Prevent duplicate saves

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Calculate final active time if currently exercising
      if (!_workoutStats['isCurrentlyResting']) {
        _workoutStats['activeTime'] +=
            now - (_workoutStats['lastExerciseStart'] as int);
      }

      // Calculate total duration in seconds
      final totalDurationSeconds = (now - _workoutStats['startTime']) ~/ 1000;

      // Calculate active time in minutes
      final activeTimeMinutes = _workoutStats['activeTime'] ~/ 60000;

      // This is the actual value that will be saved to the database
      final durationInMinutes = totalDurationSeconds ~/ 60;

      // Ensure exercises array is not empty
      if (_workoutStats['exercises'].isEmpty) {
        print(
            'Warning: No exercises in workout history. Adding current exercise.');
        final exercise = widget.exercises[currentExerciseIndex];
        _workoutStats['exercises'].add({
          'name': exercise['name'],
          'completedSets': currentSet,
          'totalSets': exercise['sets'],
          'reps': exercise['reps'],
          'primaryMuscles': exercise['primaryMuscles'] ?? [],
          'secondaryMuscles': exercise['secondaryMuscles'] ?? [],
        });
      } else {
        // Make sure all exercises have muscle data
        for (var i = 0; i < _workoutStats['exercises'].length; i++) {
          var exercise = _workoutStats['exercises'][i];
          // Find the corresponding original exercise data to get muscle information
          for (var originalExercise in widget.exercises) {
            if (originalExercise['name'] == exercise['name']) {
              // Add muscle data if not already present
              if (!exercise.containsKey('primaryMuscles')) {
                exercise['primaryMuscles'] =
                    originalExercise['primaryMuscles'] ?? [];
              }
              if (!exercise.containsKey('secondaryMuscles')) {
                exercise['secondaryMuscles'] =
                    originalExercise['secondaryMuscles'] ?? [];
              }
              break;
            }
          }
        }
      }

      // Create workout history document with comprehensive timing data
      var workoutData = {
        'userId': widget.userId,
        'planId': widget.workoutPlanId,
        'planName': widget.workoutPlanName,
        'date': FieldValue.serverTimestamp(),
        'totalSets': _workoutStats['totalSets'],
        'totalRestTime': _workoutStats['totalRestTime'],
        'totalDurationSeconds': totalDurationSeconds,
        'durationMinutes':
            durationInMinutes, // This value will be shown in the UI
        'activeTimeMinutes':
            activeTimeMinutes, // Time actually spent exercising
        'exercises': _workoutStats['exercises'],
        'statsProcessed': false,
        // Add unique identifier to ensure listeners detect it as a new document
        'completedAt': now,
      };

      print('Saving workout history with duration: ${durationInMinutes}min');
      print('Total workout duration in seconds: ${totalDurationSeconds}');
      print('Active exercise time in minutes: ${activeTimeMinutes}');
      print('Exercise data: ${_workoutStats['exercises']}');

      // Add the document to Firestore
      DocumentReference docRef =
          await _firestore.collection('workout_history').add(workoutData);

      print('Workout history saved successfully with ID: ${docRef.id}');

      // Now process workout for stats immediately
      await _updateMuscleStats();
    } catch (e, stackTrace) {
      print('Error saving workout history: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _updateMuscleStats() async {
    try {
      // First load current stats
      final currentStats =
          await _muscleProgressService.loadMuscleStats(widget.userId);

      print('ExerciseExecutionView: Loaded current stats: $currentStats');
      print(
          'ExerciseExecutionView: Processing ${_workoutStats['exercises'].length} exercises for stats update');

      // Process each exercise
      for (final exercise in _workoutStats['exercises']) {
        final primaryMuscles =
            List<dynamic>.from(exercise['primaryMuscles'] ?? []);
        final secondaryMuscles =
            List<dynamic>.from(exercise['secondaryMuscles'] ?? []);

        print('ExerciseExecutionView: Processing exercise ${exercise['name']}');
        print('ExerciseExecutionView: Primary muscles: $primaryMuscles');
        print('ExerciseExecutionView: Secondary muscles: $secondaryMuscles');

        // Update the stats for this exercise's muscles
        final updatedStats = await _muscleProgressService.updateMuscleProgress(
          userId: widget.userId,
          primaryMuscles: primaryMuscles,
          secondaryMuscles: secondaryMuscles,
          currentStats: currentStats,
        );

        // Update our local reference to the latest stats
        currentStats.clear();
        currentStats.addAll(updatedStats);
      }

      print('ExerciseExecutionView: Muscle stats updated successfully');
    } catch (e, stackTrace) {
      print('ExerciseExecutionView: Error updating muscle stats: $e');
      print('ExerciseExecutionView: Stack trace: $stackTrace');
    }
  }

  void showWorkoutCompletedDialog() {
    // Save workout history
    _saveWorkoutHistory();

    // Check for achievements and trigger notifications after workout completion
    Future.delayed(Duration(milliseconds: 500), () {
      _achievementService.checkWorkoutAchievements(widget.userId, context);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Column(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: TColor.primary,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Workout Completed!',
              style: TextStyle(
                color: TColor.primary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You\'ve successfully completed\nall exercises in this workout.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TColor.secondaryText,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TColor.primary,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'Finish Workout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget _buildMetricsCard() {
    final exercise = widget.exercises[currentExerciseIndex];

    // Get primary and secondary muscles
    final List<dynamic> primaryMuscles = exercise['primaryMuscles'] ?? [];
    final List<dynamic> secondaryMuscles = exercise['secondaryMuscles'] ?? [];

    // Categorize muscles
    Map<String, bool> muscleCategories = {
      'CHEST': _containsMuscleInCategory(
          primaryMuscles, secondaryMuscles, ['chest']),
      'BACK': _containsMuscleInCategory(primaryMuscles, secondaryMuscles,
          ['middle back', 'lower back', 'lats', 'traps', 'neck']),
      'ARMS': _containsMuscleInCategory(
          primaryMuscles, secondaryMuscles, ['biceps', 'triceps', 'forearms']),
      'ABDOMINALS': _containsMuscleInCategory(
          primaryMuscles, secondaryMuscles, ['abdominals']),
      'LEGS': _containsMuscleInCategory(primaryMuscles, secondaryMuscles, [
        'hamstrings',
        'abductors',
        'quadriceps',
        'calves',
        'glutes',
        'adductors'
      ]),
      'SHOULDERS': _containsMuscleInCategory(
          primaryMuscles, secondaryMuscles, ['shoulders']),
    };

    return Column(
      children: [
        // Add vertical spacing to create separation from image
        SizedBox(height: 10),

        // Muscle categories section - made smaller and with more padding
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: TColor.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children:
                muscleCategories.entries.where((e) => e.value).map((entry) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getMuscleColor(entry.key).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getMuscleColor(entry.key),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getMuscleIcon(entry.key),
                      size: 12, // Reduced icon size
                      color: _getMuscleColor(entry.key),
                    ),
                    SizedBox(width: 3),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11, // Reduced font size
                        fontWeight: FontWeight.w600,
                        color: _getMuscleColor(entry.key),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // Smaller and more compact metrics card
        Container(
          margin: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TColor.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactMetricItem('SET', '$currentSet/${exercise['sets']}',
                  TColor.primary, Icons.repeat),
              _buildDivider(),
              _buildCompactMetricItem('REPS', '${exercise['reps']}',
                  TColor.primary, Icons.fitness_center),
              _buildDivider(),
              _buildCompactMetricItem('REST', '${exercise['restTime']}s',
                  TColor.primary, Icons.timer),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _buildCompactMetricItem(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to determine if any muscle in a category is targeted
  bool _containsMuscleInCategory(List<dynamic> primary, List<dynamic> secondary,
      List<String> categoryMuscles) {
    for (final muscle in categoryMuscles) {
      if (primary.contains(muscle) || secondary.contains(muscle)) {
        return true;
      }
    }
    return false;
  }

  // Get appropriate icon for muscle category
  IconData _getMuscleIcon(String category) {
    switch (category) {
      case 'CHEST':
        return Icons.accessibility_new;
      case 'BACK':
        return Icons.airline_seat_flat;
      case 'ARMS':
        return Icons.fitness_center;
      case 'ABDOMINALS':
        return Icons.straighten;
      case 'LEGS':
        return Icons.directions_walk;
      case 'SHOULDERS':
        return Icons.architecture;
      default:
        return Icons.circle;
    }
  }

  // Get color for muscle category
  Color _getMuscleColor(String category) {
    switch (category) {
      case 'CHEST':
        return Colors.red[700]!;
      case 'BACK':
        return Colors.blue[700]!;
      case 'ARMS':
        return Colors.green[700]!;
      case 'ABDOMINALS':
        return Colors.orange[700]!;
      case 'LEGS':
        return Colors.purple[700]!;
      case 'SHOULDERS':
        return Colors.teal[700]!;
      default:
        return TColor.primary;
    }
  }

  Widget _buildRestTimer() {
    final exercise = widget.exercises[currentExerciseIndex];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: TColor.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'REST TIME',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: TColor.primary,
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$remainingSeconds',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: TColor.primary,
                ),
              ),
              Text(
                ' seconds',
                style: TextStyle(
                  fontSize: 18,
                  color: TColor.secondaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: LinearProgressIndicator(
              value: timerProgress,
              backgroundColor: TColor.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(TColor.primary),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (currentSet < (exercise['sets'] as int))
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Get ready for Set ${currentSet + 1}!',
                style: TextStyle(
                  fontSize: 16,
                  color: TColor.secondaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercises[currentExerciseIndex];
    final imageUrl =
        'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/${exercise['images']?[0]}';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: TColor.primary,
          title: Text(exercise['name']),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              _onWillPop().then((value) {
                if (value) {
                  Navigator.of(context).pop();
                }
              });
            },
          ),
        ),
        body: SafeArea(
          child: isWorkoutTransition
              ? Center(child: _buildWorkoutTransitionTimer())
              : Column(
                  children: [
                    // Exercise Image - with clear bottom padding
                    Container(
                      height: MediaQuery.of(context).size.height *
                          0.28, // Slightly reduced height
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 5), // Add bottom margin
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
                      ),
                    ),

                    // Metrics Card
                    _buildMetricsCard(),

                    if (isResting) _buildRestTimer(),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instructions:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: TColor.primary,
                              ),
                            ),
                            SizedBox(height: 10),
                            Expanded(
                              child: ListView(
                                children: (exercise['instructions']
                                        as List<dynamic>)
                                    .map((instruction) => Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.arrow_right,
                                                  color: TColor.primary),
                                              Expanded(
                                                child: Text(
                                                  instruction,
                                                  style:
                                                      TextStyle(fontSize: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                            if (!isResting)
                              Center(
                                child: RoundButton(
                                  title: "Complete Set",
                                  onPressed: startRestTimer,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
