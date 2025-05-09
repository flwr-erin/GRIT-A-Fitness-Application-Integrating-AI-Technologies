import 'package:fitness_app/common/exercise_detail_view.dart';
import 'package:fitness_app/view/exercise_selection_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../common/color_extension.dart';

class WorkoutRoutineView extends StatefulWidget {
  final String routineName;
  final String username; // Add username parameter
  final String planId; // Add planId parameter

  const WorkoutRoutineView({
    Key? key,
    required this.routineName,
    required this.username,
    required this.planId,
  }) : super(key: key);

  @override
  State<WorkoutRoutineView> createState() => _WorkoutRoutineViewState();
}

class _WorkoutRoutineViewState extends State<WorkoutRoutineView> {
  final Map<String, List<Map<String, dynamic>>> weeklyWorkouts = {
    "Mon": [],
    "Tue": [],
    "Wed": [],
    "Thu": [],
    "Fri": [],
    "Sat": [],
    "Sun": [],
  };

  String selectedDay = 'Mon'; // Add this line for tracking selected day
  String? _currentPlanId;

  // Add multi-day selection variables
  bool _multiDaySelectionMode = false;
  Set<String> _selectedDays = {'Mon'}; // Initialize with default day

  Future<void> _updateDatabase() async {
    try {
      if (_currentPlanId == null) {
        await _getOrCreatePlanId();
      }

      final planRef = FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(_currentPlanId);

      // Get the document first to make sure it exists
      final docSnapshot = await planRef.get();
      if (!docSnapshot.exists) {
        // Create the document with empty structure if it doesn't exist
        await planRef.set({
          'name': widget.routineName,
          'userId': widget.username,
          'createdAt': FieldValue.serverTimestamp(),
          'exercises': {},
        });
      }

      final Map<String, dynamic> exercisesByDay = {};
      weeklyWorkouts.forEach((day, exercises) {
        // Only include days with exercises
        if (exercises.isNotEmpty) {
          exercisesByDay[day] = exercises
              .map((e) => {
                    'name': e['name'],
                    'sets': e['sets'],
                    'reps': e['reps'],
                    'restTime': e['restTime'],
                    'exerciseData': e['exercise'],
                  })
              .toList();
        }
      });

      // Now update the document with our exercises data
      await planRef.update({
        'exercises': exercisesByDay,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating workout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating workout: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addExercise(String day) async {
    // Check if adding to this day would result in all days having exercises
    Set<String> simulatedSelection = {day};
    if (_wouldResultInAllDaysWithExercises(simulatedSelection)) {
      bool proceed = await _showRestDayWarning();
      if (!proceed) return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSelectionView(
          onExerciseSelected: (exercise, sets, reps) async {
            setState(() {
              weeklyWorkouts[day]?.add({
                'name': exercise['name'],
                'sets': sets,
                'reps': reps,
                'exercise': exercise, // Store the full exercise data
                'restTime': exercise['restTime'] ??
                    60, // Add default rest time if none provided
              });
            });
            await _updateDatabase(); // Add this line to save changes
          },
          username: widget.username, // Pass username here
        ),
      ),
    );
  }

  // Add new method for multi-day exercise addition
  void _addExerciseToMultipleDays() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one day'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Check if adding to selected days would result in all days having exercises
    if (_wouldResultInAllDaysWithExercises(_selectedDays)) {
      bool proceed = await _showRestDayWarning();
      if (!proceed) return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSelectionView(
          onExerciseSelected: (exercise, sets, reps) async {
            setState(() {
              // Add to all selected days
              for (String day in _selectedDays) {
                weeklyWorkouts[day]?.add({
                  'name': exercise['name'],
                  'sets': sets,
                  'reps': reps,
                  'exercise': exercise,
                  'restTime': exercise['restTime'] ?? 60,
                });
              }
            });
            await _updateDatabase();

            // Exit multi-day mode after adding
            setState(() {
              _multiDaySelectionMode = false;
              selectedDay = _selectedDays.first; // Set to first selected day
              _selectedDays = {selectedDay}; // Reset to only active day
            });
          },
          username: widget.username,
        ),
      ),
    );
  }

  // Add method to toggle multi-day selection mode
  void _toggleMultiDaySelectionMode() {
    setState(() {
      _multiDaySelectionMode = !_multiDaySelectionMode;
      // If exiting multi-day mode, reset to just the currently selected day
      if (!_multiDaySelectionMode) {
        _selectedDays = {selectedDay};
      }
    });
  }

  // Check if all days of the week have exercises planned
  bool _willAllDaysHaveExercises() {
    // Count days that already have exercises
    final daysWithExercises = weeklyWorkouts.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toSet();

    // Add the days that will receive exercises from current selection
    final allDaysAfterAdd = {...daysWithExercises, ..._selectedDays};

    // Return true if all 7 days will have exercises
    return allDaysAfterAdd.length == 7;
  }

  // Show warning popup about exercising every day
  Future<bool> _showRestDayWarning() async {
    bool proceedAnyway = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text(
              'Missing Rest Days',
              style: TextStyle(
                color: TColor.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Quicksand',
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'re planning to exercise every day of the week!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'Rest days are essential for:',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 10),
            _buildBulletPoint('Muscle recovery and growth'),
            _buildBulletPoint('Preventing injury and burnout'),
            _buildBulletPoint('Reducing mental fatigue'),
            _buildBulletPoint('Improving overall performance'),
            SizedBox(height: 15),
            Text(
              'Fitness experts recommend at least 1-2 rest days per week.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              proceedAnyway = false;
              Navigator.pop(context);
            },
            child: Text(
              'Adjust My Plan',
              style: TextStyle(
                color: TColor.primary,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              proceedAnyway = true;
              Navigator.pop(context);
            },
            child: Text(
              'Continue Anyway',
              style: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Quicksand',
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
      ),
    );

    return proceedAnyway;
  }

  // Helper for building bullet points
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  fontSize: 16,
                  color: TColor.primary,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Handle day selection based on mode
  void _handleDaySelection(String day) {
    setState(() {
      if (_multiDaySelectionMode) {
        // In multi-select mode, toggle selection
        if (_selectedDays.contains(day)) {
          // Don't allow deselecting all days
          if (_selectedDays.length > 1) {
            _selectedDays.remove(day);
          }
        } else {
          _selectedDays.add(day);
        }
      } else {
        // In single select mode, just change the selected day
        selectedDay = day;
        _selectedDays = {day};
      }
    });
  }

  void _showEditDialog(Map<String, dynamic> exercise, String day, int index) {
    int sets = exercise['sets'];
    int reps = exercise['reps'];
    int restTime = exercise['restTime'] ?? 60;

    // Create controllers with initial values
    final setsController = TextEditingController(text: sets.toString());
    final repsController = TextEditingController(text: reps.toString());
    final restTimeController = TextEditingController(text: restTime.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Edit Exercise Details',
          style: TextStyle(
            color: TColor.primary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Quicksand',
          ),
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                exercise['name'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TColor.gray,
                  fontFamily: 'Quicksand',
                ),
              ),
              SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Sets',
                        labelStyle: TextStyle(color: TColor.gray),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: TColor.primary),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: TColor.gray.withOpacity(0.3)),
                        ),
                        prefixIcon:
                            Icon(Icons.fitness_center, color: TColor.primary),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      controller: setsController,
                      onChanged: (value) => sets = int.tryParse(value) ?? sets,
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Reps',
                        labelStyle: TextStyle(color: TColor.gray),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: TColor.primary),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: TColor.gray.withOpacity(0.3)),
                        ),
                        prefixIcon: Icon(Icons.repeat, color: TColor.primary),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      controller: repsController,
                      onChanged: (value) => reps = int.tryParse(value) ?? reps,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Rest Time (seconds)',
                  labelStyle: TextStyle(color: TColor.gray),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: TColor.primary),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: TColor.gray.withOpacity(0.3)),
                  ),
                  prefixIcon: Icon(Icons.timer, color: TColor.primary),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                controller: restTimeController,
                onChanged: (value) =>
                    restTime = int.tryParse(value) ?? restTime,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: TColor.gray,
                fontFamily: 'Quicksand',
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              setState(() {
                weeklyWorkouts[day]![index]['sets'] = sets;
                weeklyWorkouts[day]![index]['reps'] = reps;
                weeklyWorkouts[day]![index]['restTime'] = restTime;
              });
              await _updateDatabase();
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
    );
  }

  String _getDayDocumentId(String day) {
    if (day.isEmpty) {
      throw ArgumentError('Day cannot be empty');
    }
    // Sanitize the day string to ensure valid document ID
    return 'day_${day.toLowerCase().trim()}';
  }

  Future<String> _getOrCreatePlanId() async {
    if (_currentPlanId != null) return _currentPlanId!;

    if (widget.planId.isNotEmpty) {
      _currentPlanId = widget.planId;
      return widget.planId;
    }

    // If we got here, something is wrong
    throw Exception('No plan ID provided and no current plan ID set');
  }

  void _saveWorkoutRoutine() async {
    try {
      await _updateDatabase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workout routine saved successfully!'),
          backgroundColor: TColor.primary,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      print('DEBUG - Save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving workout routine. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExistingWorkout();
  }

  Future<void> _loadExistingWorkout() async {
    try {
      // Set the current plan ID first
      _currentPlanId = widget.planId;

      final planRef = FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(widget.planId);

      final planDoc = await planRef.get();
      if (!planDoc.exists) {
        print('DEBUG: Plan document does not exist');
        return;
      }

      final exercisesByDay =
          planDoc.data()?['exercises'] as Map<String, dynamic>?;

      if (exercisesByDay != null && mounted) {
        setState(() {
          weeklyWorkouts.keys.forEach((day) {
            if (exercisesByDay.containsKey(day)) {
              final exercises =
                  List<Map<String, dynamic>>.from(exercisesByDay[day] ?? []);
              weeklyWorkouts[day] = exercises
                  .map((e) => {
                        'name': e['name'],
                        'sets': e['sets'],
                        'reps': e['reps'],
                        'restTime': e['restTime'] ?? 60,
                        'exercise': e['exerciseData'],
                      })
                  .toList();
            } else {
              weeklyWorkouts[day] = []; // Reset days without exercises
            }
          });
        });
      }
    } catch (e) {
      print('DEBUG - Load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyDayCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/json/img/rest.png', // Add this image to your assets or use a different one
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.hotel, size: 100, color: TColor.primary),
            ),
            SizedBox(height: 20),
            Text(
              'Rest Day',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: TColor.primary,
                fontFamily: 'Quicksand',
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Tap + to add exercises',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Quicksand',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExercise(String day, int index) async {
    setState(() {
      weeklyWorkouts[day]?.removeAt(index);
    });
    await _updateDatabase(); // Add this line to save changes
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 15),
      elevation: 4,
      shadowColor: TColor.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (exercise['exercise']['images'] != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.asset(
                    'assets/json/img/${exercise['exercise']['images'][0]}',
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Add exercise name directly on the image
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Text(
                    exercise['name'],
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 2.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exercise['exercise']['images'] == null)
                  Text(
                    exercise['name'],
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TColor.primary,
                    ),
                  ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                          'Sets', exercise['sets'].toString(), Icons.repeat),
                      _buildDivider(),
                      _buildStatItem('Reps', exercise['reps'].toString(),
                          Icons.fitness_center),
                      _buildDivider(),
                      _buildStatItem(
                          'Rest', '${exercise['restTime']}s', Icons.timer),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      label: 'Edit',
                      icon: Icons.edit,
                      color: TColor.primary,
                      onPressed: () =>
                          _showEditDialog(exercise, selectedDay, index),
                    ),
                    _buildActionButton(
                      label: 'Details',
                      icon: Icons.info_outline,
                      color: TColor.gray,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExerciseDetailView(
                              exercise: exercise['exercise'],
                            ),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      label: 'Remove',
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onPressed: () => _deleteExercise(selectedDay, index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for UI components
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: TColor.primary),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildActionButton(
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }

  // Fix: Add a WillPopScope to handle back button press
  Future<bool> _onWillPop() async {
    // If in multi-day selection mode, exit that mode instead of leaving the screen
    if (_multiDaySelectionMode) {
      setState(() {
        _multiDaySelectionMode = false;
        _selectedDays = {selectedDay};
      });
      return false; // Don't leave the screen
    }
    return true; // Allow the back action
  }

  // Check if adding exercises to the selected days would result in all days having exercises
  bool _wouldResultInAllDaysWithExercises(Set<String> selectedDays) {
    Set<String> daysWithExercises = {};

    // Add days that already have exercises
    weeklyWorkouts.forEach((day, exercises) {
      if (exercises.isNotEmpty) {
        daysWithExercises.add(day);
      }
    });

    // Add days that will now have exercises
    daysWithExercises.addAll(selectedDays);

    // If all 7 days will have exercises, return true
    return daysWithExercises.length == 7;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // Add WillPopScope handler
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.routineName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Quicksand',
            ),
          ),
          backgroundColor: TColor.primary,
          elevation: 2,
          actions: [
            // Add multi-day toggle button with improved tooltip
            Tooltip(
              message: _multiDaySelectionMode
                  ? 'Exit Multi-Day Selection Mode'
                  : 'Select Multiple Days',
              child: IconButton(
                icon: Icon(
                  _multiDaySelectionMode
                      ? Icons.check_circle
                      : Icons.date_range,
                  color: Colors.white,
                ),
                onPressed: _toggleMultiDaySelectionMode,
              ),
            ),
            Tooltip(
              message: 'Save Routine',
              child: IconButton(
                icon: Icon(Icons.save, color: Colors.white),
                onPressed: _saveWorkoutRoutine,
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              // Improved day selector card
              Card(
                elevation: 5,
                shadowColor: TColor.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _multiDaySelectionMode
                            ? "Select Multiple Days"
                            : "Select Workout Day",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: TColor.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: weeklyWorkouts.keys.map((day) {
                          final isSelected = _selectedDays.contains(day);
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            margin: EdgeInsets.symmetric(horizontal: 2),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? TColor.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: TColor.primary.withOpacity(0.3),
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      )
                                    ]
                                  : null,
                              border: _multiDaySelectionMode && !isSelected
                                  ? Border.all(color: TColor.primary, width: 2)
                                  : isSelected
                                      ? null
                                      : Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _handleDaySelection(day),
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      day,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_multiDaySelectionMode && isSelected)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.check,
                                              color: TColor.primary,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Add info text when in multi-day mode with improved styling
                    if (_multiDaySelectionMode && _selectedDays.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: TColor.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Selected: ${_selectedDays.join(", ")}',
                          style: TextStyle(
                            color: TColor.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 15),
              Expanded(
                child: Card(
                  elevation: 5,
                  shadowColor: TColor.primary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: (_multiDaySelectionMode)
                            // Improved multi-day selection UI
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: TColor.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.calendar_month,
                                          size: 40, color: TColor.primary),
                                    ),
                                    SizedBox(height: 24),
                                    Text(
                                      'Multi-Day Selection Mode',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: TColor.primary,
                                        fontFamily: 'Quicksand',
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Days: ${_selectedDays.join(", ")}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[800],
                                          fontFamily: 'Quicksand',
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 30),
                                    ElevatedButton.icon(
                                      onPressed: _addExerciseToMultipleDays,
                                      icon: Icon(Icons.add),
                                      label: Text(
                                        'Add Exercise to Selected Days',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: TColor.primary,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : (weeklyWorkouts[selectedDay]?.isEmpty ?? true)
                                ? _buildEmptyDayCard()
                                : ListView.builder(
                                    itemCount:
                                        weeklyWorkouts[selectedDay]?.length ??
                                            0,
                                    itemBuilder: (context, index) {
                                      Map<String, dynamic> exercise =
                                          weeklyWorkouts[selectedDay]![index];
                                      return _buildExerciseCard(
                                          exercise, index);
                                    },
                                  ),
                      ),
                      // Only show FAB in single-day mode
                      if (!_multiDaySelectionMode)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton(
                            backgroundColor: TColor.primary,
                            onPressed: () => _addExercise(selectedDay),
                            child: Icon(Icons.add),
                            elevation: 5,
                            tooltip: 'Add Exercise',
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
