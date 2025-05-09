import 'package:fitness_app/view/startworkout_view.dart';
import 'package:fitness_app/view/workout_routine_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../common/color_extension.dart';
import '../services/muscle_progress_service.dart';

class WorkoutView extends StatefulWidget {
  final String username; // Add username parameter
  final String userId; // Add userId parameter
  const WorkoutView({super.key, required this.username, required this.userId});

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<WorkoutView>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> workoutPlans = [];
  String? selectedPlanId;
  late TabController _tabController;
  List<Map<String, dynamic>> workoutHistory = [];
  bool isHistoryLoading = true;
  final MuscleProgressService _muscleProgressService = MuscleProgressService();
  bool _hasExercisesToday = false;
  int _userFitnessLevel = 0; // 0=beginner, 1=intermediate, 2=expert

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWorkoutPlans();
    _loadSelectedPlan();
    _loadWorkoutHistory();
    _loadUserFitnessLevel(); // Load the user's fitness level
  }

  // Load user fitness level from the database
  Future<void> _loadUserFitnessLevel() async {
    try {
      // Use username instead of userId for user_profiles collection
      final userProfileDoc = await _firestore
          .collection('user_profiles')
          .doc(widget.username)
          .get();

      if (userProfileDoc.exists && userProfileDoc.data() != null) {
        final userData = userProfileDoc.data()!;
        print('Fetched fitnessLevel: ${userData['fitnessLevel']}'); // Debug log
        setState(() {
          // Default to beginner (0) if not specified
          _userFitnessLevel = userData['fitnessLevel'] ?? 0;
        });
      } else {
        print(
            'User profile document does not exist or has no data.'); // Debug log
      }
    } catch (e) {
      print('Error loading user fitness level: $e');
      // Default to beginner level if there's an error
      setState(() {
        _userFitnessLevel = 0;
      });
    }
  }

  // Get fitness level text representation
  String _getFitnessLevelText() {
    switch (_userFitnessLevel) {
      case 0:
        return 'Beginner';
      case 1:
        return 'Intermediate';
      case 2:
        return 'Expert';
      default:
        return 'Beginner';
    }
  }

  // Get fitness level color
  Color _getFitnessLevelColor() {
    switch (_userFitnessLevel) {
      case 0:
        return TColor.primary; // Beginner - use theme primary color
      case 1:
        return Color(0xFFFF9800); // Intermediate - orange that matches theme
      case 2:
        return Color(0xFFE53935); // Expert - red that matches theme
      default:
        return TColor.primary;
    }
  }

  // Get fitness level icon
  IconData _getFitnessLevelIcon() {
    switch (_userFitnessLevel) {
      case 0:
        return Icons.fitness_center;
      case 1:
        return Icons.trending_up;
      case 2:
        return Icons.whatshot;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getCurrentDay() {
    int currentDay = DateTime.now().weekday;
    List<String> days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return days[(currentDay % 7)];
  }

  bool hasWorkoutToday() {
    return _hasExercisesToday;
  }

  Future<void> _checkTodaysExercises() async {
    if (selectedPlanId == null) {
      setState(() {
        _hasExercisesToday = false;
      });
      return;
    }

    try {
      final String today = _getCurrentDay();
      final docSnapshot = await _firestore
          .collection('workout_plans')
          .doc(selectedPlanId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('exercises')) {
          final exercises = data['exercises'] as Map<String, dynamic>;
          final todaysExercises = exercises[today] as List<dynamic>?;

          setState(() {
            _hasExercisesToday =
                todaysExercises != null && todaysExercises.isNotEmpty;
          });
          return;
        }
      }

      setState(() {
        _hasExercisesToday = false;
      });
    } catch (e) {
      print('Error checking today\'s exercises: $e');
      setState(() {
        _hasExercisesToday = false;
      });
    }
  }

  Future<void> _loadSelectedPlan() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();

      // Check if document exists and has data
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;

        // Check if selectedWorkoutPlan field exists and is of correct type
        if (userData.containsKey('selectedWorkoutPlan')) {
          setState(() {
            selectedPlanId = userData['selectedWorkoutPlan'] as String?;
          });

          // Check for exercises today after loading selected plan
          await _checkTodaysExercises();
        } else {
          print('No selectedWorkoutPlan field found in user document');
          setState(() {
            selectedPlanId = null;
            _hasExercisesToday = false;
          });
        }
      } else {
        print('User document not found');
        setState(() {
          selectedPlanId = null;
          _hasExercisesToday = false;
        });
      }
    } catch (e) {
      print('Error loading selected plan: $e');
      setState(() {
        selectedPlanId = null;
        _hasExercisesToday = false;
      });
    }
  }

  Future<void> _setSelectedPlan(String planId) async {
    try {
      // If the plan is already selected, unselect it
      final newSelectedPlanId = selectedPlanId == planId ? null : planId;

      await _firestore.collection('users').doc(widget.userId).update({
        'selectedWorkoutPlan': newSelectedPlanId,
      });

      setState(() {
        selectedPlanId = newSelectedPlanId;
      });

      // Check for exercises today after changing selected plan
      await _checkTodaysExercises();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(newSelectedPlanId == null
                ? 'Workout plan unselected'
                : 'Workout plan selected as default')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update workout plan selection')),
      );
    }
  }

  Future<void> _loadWorkoutPlans() async {
    try {
      setState(() {
        workoutPlans = [];
      });

      // Define the specific user ID whose workout plans should be visible to all users
      const String sharedUserId = '4yhqNMLnTbTcshslOMZ8';
      // User ID for beginner-specific workout plans
      const String beginnerPlansUserId = 'GXQhP63pA20wi675hX0B';
      // User ID for intermediate-specific workout plans
      const String intermediatePlansUserId = 'YP0abFg8kdNXMXwRU7Zg';
      // User ID for expert-specific workout plans
      const String expertPlansUserId = 'IX0LJ1TlsnOf1YWoTdpE';

      // First, get the current user's workout plans
      final userSnapshot = await _firestore
          .collection('workout_plans')
          .where('userId', isEqualTo: widget.userId)
          .get();

      // Then, get the shared workout plans
      final sharedSnapshot = await _firestore
          .collection('workout_plans')
          .where('userId', isEqualTo: sharedUserId)
          .get();

      // Get beginner workout plans only if user's fitness level is beginner (0)
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> beginnerPlans =
          [];
      if (_userFitnessLevel == 0) {
        // Only for beginners
        final beginnerSnapshot = await _firestore
            .collection('workout_plans')
            .where('userId', isEqualTo: beginnerPlansUserId)
            .get();
        beginnerPlans.addAll(beginnerSnapshot.docs);
      }

      // Get intermediate workout plans only if user's fitness level is intermediate (1)
      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          intermediatePlans = [];
      if (_userFitnessLevel == 1) {
        // Only for intermediate users
        final intermediateSnapshot = await _firestore
            .collection('workout_plans')
            .where('userId', isEqualTo: intermediatePlansUserId)
            .get();
        intermediatePlans.addAll(intermediateSnapshot.docs);
      }

      // Get expert workout plans only if user's fitness level is expert (2)
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> expertPlans = [];
      if (_userFitnessLevel == 2) {
        // Only for expert users
        final expertSnapshot = await _firestore
            .collection('workout_plans')
            .where('userId', isEqualTo: expertPlansUserId)
            .get();
        expertPlans.addAll(expertSnapshot.docs);
      }

      if (mounted) {
        // Combine both query results
        final List<Map<String, dynamic>> combinedPlans = [];

        // Add the user's own workout plans
        combinedPlans.addAll(userSnapshot.docs.map((doc) => {
              ...doc.data(),
              'id': doc.id,
              'isShared': false, // Flag to indicate it's the user's own plan
            }));

        // Add the shared workout plans
        combinedPlans.addAll(sharedSnapshot.docs.map((doc) => {
              ...doc.data(),
              'id': doc.id,
              'isShared': true, // Flag to indicate it's a shared plan
            }));

        // Add beginner workout plans if applicable
        if (_userFitnessLevel == 0) {
          combinedPlans.addAll(beginnerPlans.map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'isShared': true, // Flag to indicate it's a shared plan
                'isBeginnerPlan': true, // Additional flag for beginner plans
              }));
        }

        // Add intermediate workout plans if applicable
        if (_userFitnessLevel == 1) {
          combinedPlans.addAll(intermediatePlans.map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'isShared': true, // Flag to indicate it's a shared plan
                'isIntermediatePlan':
                    true, // Additional flag for intermediate plans
              }));
        }

        // Add expert workout plans if applicable
        if (_userFitnessLevel == 2) {
          combinedPlans.addAll(expertPlans.map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'isShared': true, // Flag to indicate it's a shared plan
                'isExpertPlan': true, // Additional flag for expert plans
              }));
        }

        // Sort combined plans by creation date
        combinedPlans.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = a['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Sort descending (newest first)
        });

        setState(() {
          workoutPlans = combinedPlans;
        });
      }
    } catch (e) {
      // Only show error if it's not the index error or if there are actually plans
      if (!e.toString().contains('requires an index')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load workout plans')),
          );
        }
      }
    }
  }

  // Add new method to edit workout plan name
  Future<void> _editWorkoutPlan(String planId, String newName) async {
    try {
      await _firestore.collection('workout_plans').doc(planId).update({
        'name': newName,
      });

      // Update local state
      setState(() {
        final index = workoutPlans.indexWhere((plan) => plan['id'] == planId);
        if (index != -1) {
          workoutPlans[index]['name'] = newName;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workout plan updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update workout plan')),
      );
    }
  }

  Future<void> _addWorkoutPlan(String planName) async {
    try {
      // Initialize with an empty structure
      final workoutPlan = {
        'name': planName,
        'userId': widget.userId, // Use userId, not username
        'username': widget.username,
        'createdAt': FieldValue.serverTimestamp(),
        'exercises': {}, // Initialize with empty object instead of array
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Show loading indicator
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(TColor.primary),
              ),
            );
          });

      // Add to Firestore
      final docRef =
          await _firestore.collection('workout_plans').add(workoutPlan);

      // Close loading indicator
      Navigator.of(context).pop();

      // Update local state
      setState(() {
        workoutPlans.add({
          'id': docRef.id,
          ...workoutPlan,
        });
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workout plan created successfully')),
      );

      // Navigate to WorkoutRoutineView
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutRoutineView(
              routineName: planName,
              username: widget.username,
              planId: docRef.id,
            ),
          ),
        ).then((_) => _loadWorkoutPlans()); // Refresh after returning
      }
    } catch (e) {
      print('Error creating workout plan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to create workout plan: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteWorkoutPlan(Map<String, dynamic> plan) async {
    // Prevent deletion of preset plans
    if (plan['isShared'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset workout plans cannot be deleted')),
      );
      return;
    }

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete Workout Plan'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are you sure you want to delete this workout plan?'),
                  SizedBox(height: 10),
                  Text(
                    '"${plan['name']}"',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'This action cannot be undone.',
                    style: TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed

    // Proceed with deletion only if confirmed
    if (confirmDelete) {
      try {
        await _firestore.collection('workout_plans').doc(plan['id']).delete();
        setState(() {
          workoutPlans.removeWhere((p) => p['id'] == plan['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workout plan deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete workout plan')),
        );
      }
    }
  }

  Future<void> _processWorkoutForStats(Map<String, dynamic> workout) async {
    if (workout['exercises'] == null) return;

    final exercises = workout['exercises'] as List<dynamic>;
    final Map<String, Map<String, dynamic>> currentStats =
        await _muscleProgressService.loadMuscleStats(widget.userId);

    for (final exercise in exercises) {
      final primaryMuscles = exercise['primaryMuscles'] as List<dynamic>? ?? [];
      final secondaryMuscles =
          exercise['secondaryMuscles'] as List<dynamic>? ?? [];

      // Only process if there are muscles to update
      if (primaryMuscles.isNotEmpty ||
          (secondaryMuscles?.isNotEmpty ?? false)) {
        final updatedStats = await _muscleProgressService.updateMuscleProgress(
          userId: widget.userId,
          primaryMuscles: primaryMuscles,
          secondaryMuscles: secondaryMuscles,
          currentStats: currentStats,
        );

        // Update local stats reference for next exercise
        currentStats.clear();
        currentStats.addAll(updatedStats);
      }
    }
  }

  Future<void> _loadWorkoutHistory() async {
    try {
      setState(() {
        isHistoryLoading = true;
      });

      print('Fetching workout history for user: ${widget.userId}');

      // Modified query to avoid requiring composite index
      final snapshot = await _firestore
          .collection('workout_history')
          .where('userId', isEqualTo: widget.userId)
          // Remove the orderBy that's causing the index error
          // .orderBy('date', descending: true)
          .limit(30)
          .get();

      print('History documents found: ${snapshot.docs.length}');

      if (mounted) {
        setState(() {
          // Get all documents and then sort locally
          workoutHistory = snapshot.docs.map((doc) {
            var data = doc.data();
            print('Document data: $data');
            return {
              ...data,
              'id': doc.id,
            };
          }).toList();

          // Sort locally by date (if documents have dates)
          workoutHistory.sort((a, b) {
            final dateA = a['date'] as Timestamp?;
            final dateB = b['date'] as Timestamp?;
            if (dateA == null || dateB == null) return 0;
            return dateB.compareTo(dateA); // Descending order (newest first)
          });

          isHistoryLoading = false;
          print('History loaded successfully: ${workoutHistory.length} items');

          // Process the most recent workout for stats if it exists and hasn't been processed
          if (workoutHistory.isNotEmpty) {
            final latestWorkout = workoutHistory.first;
            if (latestWorkout['statsProcessed'] != true) {
              _processWorkoutForStats(latestWorkout).then((_) {
                // Mark workout as processed
                _firestore
                    .collection('workout_history')
                    .doc(latestWorkout['id'])
                    .update({'statsProcessed': true}).catchError(
                        (e) => print('Error marking workout as processed: $e'));
              });
            }
          }
        });
      }
    } catch (e, stackTrace) {
      print('Error loading workout history: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          isHistoryLoading = false;
          // Still try to load without sorting if that was the issue
          _loadWorkoutHistoryFallback();
        });
      }
    }
  }

  // Fallback method without any querying complexity
  Future<void> _loadWorkoutHistoryFallback() async {
    try {
      final snapshot = await _firestore
          .collection('workout_history')
          .where('userId', isEqualTo: widget.userId)
          .get();

      if (mounted) {
        setState(() {
          workoutHistory = snapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();

          // Manual sorting if possible
          try {
            workoutHistory.sort((a, b) {
              final dateA = a['date'] as Timestamp?;
              final dateB = b['date'] as Timestamp?;
              if (dateA == null || dateB == null) return 0;
              return dateB.compareTo(dateA);
            });
          } catch (sortError) {
            print('Could not sort history: $sortError');
          }
        });
      }
    } catch (e) {
      print('Fallback history load also failed: $e');
    }
  }

  // Add helper methods for muscle categories
  bool _containsMuscleInCategory(List<dynamic> primary,
      List<dynamic>? secondary, List<String> categoryMuscles) {
    for (final muscle in categoryMuscles) {
      if (primary.contains(muscle) || (secondary ?? []).contains(muscle)) {
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

  // Build muscle category chips
  Widget _buildMuscleCategories(Map<String, bool> categories) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: categories.entries.where((e) => e.value).map((entry) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: _getMuscleColor(entry.key).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
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
                size: 10,
                color: _getMuscleColor(entry.key),
              ),
              SizedBox(width: 2),
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _getMuscleColor(entry.key),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Categorize muscles from workout history
  Map<String, bool> _categorizeMusclesForExercise(Map<String, dynamic> exercise,
      List<String> primaryMuscles, List<String>? secondaryMuscles) {
    return {
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
  }

  // Fetch muscle data for an exercise
  Future<Map<String, List<String>>> _fetchMuscleDataForExercise(
      String exerciseName) async {
    try {
      // First try to load from Firestore
      final exerciseDoc = await _firestore
          .collection('exercises')
          .where('name', isEqualTo: exerciseName)
          .limit(1)
          .get();

      if (exerciseDoc.docs.isNotEmpty) {
        final data = exerciseDoc.docs.first.data();
        return {
          'primaryMuscles': List<String>.from(data['primaryMuscles'] ?? []),
          'secondaryMuscles': List<String>.from(data['secondaryMuscles'] ?? []),
        };
      }

      // Return empty lists if not found
      return {
        'primaryMuscles': [],
        'secondaryMuscles': [],
      };
    } catch (e) {
      print('Error fetching muscle data: $e');
      return {
        'primaryMuscles': [],
        'secondaryMuscles': [],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate plans into user plans and preset plans
    final userPlans =
        workoutPlans.where((plan) => plan['isShared'] != true).toList();
    final presetPlans =
        workoutPlans.where((plan) => plan['isShared'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TColor.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: TColor.primary,
        centerTitle: true,
        elevation: 10.0,
        shadowColor: Colors.black.withOpacity(0.5),
        title: Text(
          "GRIT",
          style: TextStyle(
              color: TColor.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: "WORKOUT PLANS"),
            Tab(text: "HISTORY"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // WORKOUT PLANS TAB
          Stack(
            children: [
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    color: TColor.primary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children:
                          ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                              .map((day) => Text(
                                    day,
                                    style: TextStyle(
                                      color: day == _getCurrentDay()
                                          ? Colors.yellow
                                          : TColor.white,
                                      fontWeight: day == _getCurrentDay()
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ))
                              .toList(),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: TColor.white,
                      child: ListView(
                        padding: EdgeInsets.only(top: 20, bottom: 80),
                        children: [
                          // Start Workout / Rest Day Card
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: hasWorkoutToday()
                                        ? TColor.primary.withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    if (hasWorkoutToday()) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StartWorkoutView(
                                            userId: widget.userId,
                                            selectedPlanId: selectedPlanId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 20, horizontal: 25),
                                    child: Row(
                                      children: [
                                        Container(
                                          height: 60,
                                          width: 60,
                                          decoration: BoxDecoration(
                                            color: hasWorkoutToday()
                                                ? TColor.primary
                                                    .withOpacity(0.15)
                                                : Colors.grey.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              hasWorkoutToday()
                                                  ? Icons.fitness_center
                                                  : Icons.self_improvement,
                                              color: hasWorkoutToday()
                                                  ? TColor.primary
                                                  : Colors.grey.shade600,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                hasWorkoutToday()
                                                    ? "Start Workout"
                                                    : "Rest Day",
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w700,
                                                  color: hasWorkoutToday()
                                                      ? TColor.primary
                                                      : Colors.grey.shade700,
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                hasWorkoutToday()
                                                    ? "Time to crush your workout!"
                                                    : "Take it easy and recover",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: hasWorkoutToday()
                                                      ? TColor.primary
                                                          .withOpacity(0.7)
                                                      : Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (hasWorkoutToday())
                                          Container(
                                            height: 36,
                                            width: 36,
                                            decoration: BoxDecoration(
                                              color: TColor.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Fitness Level Badge
                          if (hasWorkoutToday())
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: _buildFitnessLevelBadge(),
                            ),

                          // Your Plans Section Header
                          if (userPlans.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.fromLTRB(20, 20, 20, 5),
                              child: Text(
                                "YOUR WORKOUT PLANS",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: TColor.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),

                          // User Plans
                          ...userPlans.map(
                              (plan) => _buildWorkoutPlanCard(plan, context)),

                          // Preset Plans Section Header with divider
                          if (presetPlans.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(
                                  height: 40,
                                  thickness: 1,
                                  indent: 20,
                                  endIndent: 20,
                                  color: Colors.grey[300],
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        color: Colors.indigo,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "PRESET WORKOUT PLANS",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                          // Preset Plans
                          ...presetPlans.map(
                              (plan) => _buildWorkoutPlanCard(plan, context)),

                          // Add space at the bottom for better UX
                          SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TColor.primary.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          String newPlanName = '';
                          return AlertDialog(
                            backgroundColor: TColor.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              'Create Workout Plan',
                              style: TextStyle(
                                color: TColor.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: TextField(
                              onChanged: (value) => newPlanName = value,
                              style: TextStyle(color: TColor.white),
                              decoration: InputDecoration(
                                hintText: 'Enter workout plan name',
                                hintStyle: TextStyle(
                                    color: TColor.white.withOpacity(0.7)),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: TColor.white),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: TColor.white),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel',
                                    style: TextStyle(color: TColor.white)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (newPlanName.isNotEmpty) {
                                    _addWorkoutPlan(newPlanName);
                                    Navigator.pop(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  'Create',
                                  style: TextStyle(color: TColor.primary),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    backgroundColor: TColor.primary,
                    child: Icon(Icons.add, color: TColor.white, size: 30),
                  ),
                ),
              ),
            ],
          ),
          RefreshIndicator(
            color: TColor.primary,
            onRefresh: () => _loadWorkoutHistory(),
            child: isHistoryLoading
                ? Center(
                    child: CircularProgressIndicator(color: TColor.primary))
                : workoutHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fitness_center,
                                size: 70,
                                color: TColor.primary.withOpacity(0.5)),
                            SizedBox(height: 20),
                            Text(
                              "No workout history yet",
                              style: TextStyle(
                                  fontSize: 20,
                                  color: TColor.secondaryText,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Complete your first workout to see it here!",
                              style: TextStyle(
                                fontSize: 16,
                                color: TColor.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(16),
                        itemCount: workoutHistory.length,
                        itemBuilder: (context, index) {
                          final workout = workoutHistory[index];

                          print('Rendering workout: $workout');

                          final date = workout['date'];
                          String formattedDate = 'Unknown date';

                          if (date is Timestamp) {
                            formattedDate = DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(date.toDate());
                          } else if (date is DateTime) {
                            formattedDate = DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(date);
                          } else if (date != null) {
                            formattedDate = date.toString();
                          }

                          final totalDuration =
                              workout['totalDurationSeconds'] ?? 0;
                          final restTime = workout['totalRestTime'] ?? 0;
                          final activeTime = totalDuration - restTime;

                          final activePercent = totalDuration > 0
                              ? (activeTime / totalDuration * 100).toInt()
                              : 0;
                          final restPercent = totalDuration > 0
                              ? (restTime / totalDuration * 100).toInt()
                              : 0;

                          return Card(
                            elevation: 3,
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          workout['planName'] ?? 'Workout',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: TColor.primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: TColor.primary,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          "${workout['durationMinutes'] ?? 0} min",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Divider(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildWorkoutStatItem(
                                        "Sets",
                                        "${workout['totalSets'] ?? 0}",
                                        Icons.fitness_center,
                                      ),
                                      _buildWorkoutStatItem(
                                        "Duration",
                                        "${workout['durationMinutes'] ?? 0}m",
                                        Icons.timer,
                                      ),
                                      _buildWorkoutStatItem(
                                        "Exercises",
                                        "${(workout['exercises'] as List?)?.length ?? 0}",
                                        Icons.format_list_numbered,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Time Distribution:",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: LinearProgressIndicator(
                                                value: totalDuration > 0
                                                    ? activeTime / totalDuration
                                                    : 0,
                                                backgroundColor:
                                                    Colors.grey.shade300,
                                                color: TColor.primary,
                                                minHeight: 8,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "$activePercent%",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: TColor.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              "Active: ${_formatSeconds(activeTime)}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: TColor.primary,
                                              ),
                                            ),
                                            Spacer(),
                                            Text(
                                              "Rest: ${_formatSeconds(restTime)}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                      colorScheme: ColorScheme.light(
                                        primary: TColor.primary,
                                      ),
                                    ),
                                    child: ExpansionTile(
                                      iconColor: TColor.primary,
                                      collapsedIconColor: TColor.primary,
                                      title: Text(
                                        "Exercise Details",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      tilePadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 0),
                                      childrenPadding: EdgeInsets.only(
                                          bottom: 8, left: 8, right: 8),
                                      children: [
                                        ...(workout['exercises'] as List?)
                                                ?.map((e) {
                                              List<dynamic> primaryMuscles =
                                                  e['primaryMuscles'] ?? [];
                                              List<dynamic> secondaryMuscles =
                                                  e['secondaryMuscles'] ?? [];

                                              Widget muscleCategories =
                                                  primaryMuscles.isEmpty &&
                                                          secondaryMuscles
                                                              .isEmpty
                                                      ? FutureBuilder<
                                                          Map<String,
                                                              List<String>>>(
                                                          future:
                                                              _fetchMuscleDataForExercise(
                                                                  e['name']),
                                                          builder: (context,
                                                              snapshot) {
                                                            if (!snapshot
                                                                .hasData) {
                                                              return SizedBox
                                                                  .shrink();
                                                            }

                                                            final muscleData =
                                                                snapshot.data!;
                                                            final fetchedPrimaryMuscles =
                                                                muscleData[
                                                                        'primaryMuscles'] ??
                                                                    [];
                                                            final fetchedSecondaryMuscles =
                                                                muscleData[
                                                                        'secondaryMuscles'] ??
                                                                    [];

                                                            final categories = {
                                                              'CHEST': _containsMuscleInCategory(
                                                                  fetchedPrimaryMuscles,
                                                                  fetchedSecondaryMuscles,
                                                                  ['chest']),
                                                              'BACK': _containsMuscleInCategory(
                                                                  fetchedPrimaryMuscles,
                                                                  fetchedSecondaryMuscles,
                                                                  [
                                                                    'middle back',
                                                                    'lower back',
                                                                    'lats',
                                                                    'traps',
                                                                    'neck'
                                                                  ]),
                                                              'ARMS': _containsMuscleInCategory(
                                                                  fetchedPrimaryMuscles,
                                                                  fetchedSecondaryMuscles,
                                                                  [
                                                                    'biceps',
                                                                    'triceps',
                                                                    'forearms'
                                                                  ]),
                                                              'ABDOMINALS':
                                                                  _containsMuscleInCategory(
                                                                      fetchedPrimaryMuscles,
                                                                      fetchedSecondaryMuscles,
                                                                      [
                                                                    'abdominals'
                                                                  ]),
                                                              'LEGS': _containsMuscleInCategory(
                                                                  fetchedPrimaryMuscles,
                                                                  fetchedSecondaryMuscles,
                                                                  [
                                                                    'hamstrings',
                                                                    'abductors',
                                                                    'quadriceps',
                                                                    'calves',
                                                                    'glutes',
                                                                    'adductors'
                                                                  ]),
                                                              'SHOULDERS':
                                                                  _containsMuscleInCategory(
                                                                      fetchedPrimaryMuscles,
                                                                      fetchedSecondaryMuscles,
                                                                      [
                                                                    'shoulders'
                                                                  ]),
                                                            };

                                                            return _buildMuscleCategories(
                                                                categories);
                                                          },
                                                        )
                                                      : _buildMuscleCategories({
                                                          'CHEST':
                                                              _containsMuscleInCategory(
                                                                  primaryMuscles,
                                                                  secondaryMuscles,
                                                                  ['chest']),
                                                          'BACK': _containsMuscleInCategory(
                                                              primaryMuscles,
                                                              secondaryMuscles,
                                                              [
                                                                'middle back',
                                                                'lower back',
                                                                'lats',
                                                                'traps',
                                                                'neck'
                                                              ]),
                                                          'ARMS': _containsMuscleInCategory(
                                                              primaryMuscles,
                                                              secondaryMuscles,
                                                              [
                                                                'biceps',
                                                                'triceps',
                                                                'forearms'
                                                              ]),
                                                          'ABDOMINALS':
                                                              _containsMuscleInCategory(
                                                                  primaryMuscles,
                                                                  secondaryMuscles,
                                                                  [
                                                                'abdominals'
                                                              ]),
                                                          'LEGS': _containsMuscleInCategory(
                                                              primaryMuscles,
                                                              secondaryMuscles,
                                                              [
                                                                'hamstrings',
                                                                'abductors',
                                                                'quadriceps',
                                                                'calves',
                                                                'glutes',
                                                                'adductors'
                                                              ]),
                                                          'SHOULDERS':
                                                              _containsMuscleInCategory(
                                                                  primaryMuscles,
                                                                  secondaryMuscles,
                                                                  [
                                                                'shoulders'
                                                              ]),
                                                        });

                                              return Padding(
                                                padding:
                                                    EdgeInsets.only(bottom: 10),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .fitness_center,
                                                            size: 16,
                                                            color:
                                                                TColor.primary),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      e['name'],
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    "${e['completedSets']}/${e['totalSets']} sets • ${e['reps']} reps",
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              Container(
                                                                margin: EdgeInsets
                                                                    .only(
                                                                        top: 4),
                                                                child:
                                                                    muscleCategories,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if ((workout['exercises']
                                                                as List)
                                                            .last !=
                                                        e)
                                                      Divider(height: 16),
                                                  ],
                                                ),
                                              );
                                            })?.toList() ??
                                            [],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutPlanCard(
      Map<String, dynamic> plan, BuildContext context) {
    final isPreset = plan['isShared'] == true;
    final isSelected = selectedPlanId == plan['id'];
    final isBeginnerPlan = plan['isBeginnerPlan'] == true;
    final isIntermediatePlan = plan['isIntermediatePlan'] == true;
    final isExpertPlan = plan['isExpertPlan'] == true;
    final isInstructorPlan =
        isPreset && plan['userId'] == '4yhqNMLnTbTcshslOMZ8';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 5,
        shadowColor: isSelected
            ? Colors.amber.withOpacity(0.5)
            : isPreset || isBeginnerPlan || isIntermediatePlan || isExpertPlan
                ? Colors.indigo.withOpacity(0.3)
                : TColor.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPreset ||
                      isBeginnerPlan ||
                      isIntermediatePlan ||
                      isExpertPlan
                  ? [
                      Color(0xFF3949AB),
                      Color(0xFF303F9F),
                    ]
                  : isSelected
                      ? [
                          TColor.primary,
                          Color.fromARGB(255, 13, 94, 96),
                        ]
                      : [
                          TColor.primary.withOpacity(0.9),
                          TColor.primary.withOpacity(0.7),
                        ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: Colors.amber, width: 2.5)
                : isPreset ||
                        isBeginnerPlan ||
                        isIntermediatePlan ||
                        isExpertPlan
                    ? Border.all(color: Colors.white.withOpacity(0.2), width: 1)
                    : Border.all(color: Colors.transparent),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  // Decorative background design elements
                  Positioned(
                    right: -10,
                    top: -15,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(
                        isPreset ||
                                isBeginnerPlan ||
                                isIntermediatePlan ||
                                isExpertPlan
                            ? Icons.auto_awesome
                            : Icons.fitness_center,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Card Content
                  Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.fromLTRB(16, 10, 16, 5),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            isBeginnerPlan
                                ? Icons.fitness_center
                                : isIntermediatePlan
                                    ? Icons.trending_up
                                    : isExpertPlan
                                        ? Icons.whatshot
                                        : isInstructorPlan
                                            ? Icons.sports_gymnastics
                                            : isPreset
                                                ? Icons.auto_awesome
                                                : Icons.fitness_center,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan['name'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              if (isBeginnerPlan)
                                Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        size: 12,
                                        color: Colors.indigo,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'BEGINNER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isIntermediatePlan)
                                Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        size: 12,
                                        color: Colors.indigo,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'INTERMEDIATE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isExpertPlan)
                                Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.whatshot,
                                        size: 12,
                                        color: Colors.indigo,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'EXPERT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isPreset && !isInstructorPlan)
                                Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.whatshot,
                                        size: 12,
                                        color: Colors.indigo,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'EXPERT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isInstructorPlan)
                                Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sports_gymnastics,
                                        size: 12,
                                        color: Colors.indigo,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'INSTRUCTOR',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  isInstructorPlan
                                      ? "Professional trainer workout"
                                      : isPreset
                                          ? "Official workout plan"
                                          : "Custom workout plan",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action buttons
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 8, 8),
                        child: Row(
                          children: [
                            // View button
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WorkoutRoutineView(
                                        routineName: plan['name'],
                                        username: widget.username,
                                        planId: plan['id'],
                                      ),
                                    ),
                                  ).then((_) => _loadWorkoutPlans());
                                },
                                icon: Icon(
                                  Icons.visibility,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: Text(
                                  'View Plan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),

                            // Action button group
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button - only for user plans
                                if (!isPreset)
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          String newName = plan['name'];
                                          return AlertDialog(
                                            backgroundColor: TColor.primary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            title: Text(
                                              'Edit Workout Plan',
                                              style: TextStyle(
                                                color: TColor.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: TextField(
                                              controller: TextEditingController(
                                                  text: plan['name']),
                                              onChanged: (value) =>
                                                  newName = value,
                                              style: TextStyle(
                                                  color: TColor.white),
                                              decoration: InputDecoration(
                                                hintText: 'Enter new plan name',
                                                hintStyle: TextStyle(
                                                    color: TColor.white
                                                        .withOpacity(0.7)),
                                                enabledBorder:
                                                    UnderlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color: TColor.white),
                                                ),
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color: TColor.white),
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text('Cancel',
                                                    style: TextStyle(
                                                        color: TColor.white)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  if (newName.isNotEmpty) {
                                                    _editWorkoutPlan(
                                                        plan['id'], newName);
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Save',
                                                  style: TextStyle(
                                                      color: TColor.primary),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    tooltip: 'Edit Plan',
                                    splashRadius: 24,
                                  ),

                                // Set as current plan button
                                IconButton(
                                  icon: Icon(
                                    isSelected
                                        ? Icons.star
                                        : Icons.star_border_outlined,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                  onPressed: () => _setSelectedPlan(plan['id']),
                                  tooltip: isSelected
                                      ? 'Unselect Plan'
                                      : 'Set as Current Plan',
                                  splashRadius: 24,
                                ),

                                // Delete button - only for user plans
                                if (!isPreset)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: () => _deleteWorkoutPlan(plan),
                                    tooltip: 'Delete Plan',
                                    splashRadius: 24,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Creation date for user plans
              if (plan['createdAt'] != null && !isPreset)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Created: ${_formatDate(plan['createdAt'])}",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: TColor.primary),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins}m ${secs}s";
  }

  // Format timestamp for display
  String _formatDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  // Build fitness level badge
  Widget _buildFitnessLevelBadge() {
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: 4),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _getFitnessLevelColor().withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: _getFitnessLevelColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFitnessLevelIcon(),
              color: _getFitnessLevelColor(),
              size: 12,
            ),
            SizedBox(width: 3),
            Text(
              _getFitnessLevelText(),
              style: TextStyle(
                color: _getFitnessLevelColor(),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
