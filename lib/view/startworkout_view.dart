import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/color_extension.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../common/round_button.dart';
import 'exercise_execution_view.dart';

class StartWorkoutView extends StatefulWidget {
  final String userId;
  final String? selectedPlanId;
  const StartWorkoutView({
    super.key,
    required this.userId,
    this.selectedPlanId,
  });

  @override
  State<StartWorkoutView> createState() => _StartWorkoutViewState();
}

class _StartWorkoutViewState extends State<StartWorkoutView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<Map<String, dynamic>>> exercisesByDay = {};
  String planName = "";
  bool isLoading = true;
  String selectedDay = "";
  int _currentExerciseIndex = 0;

  @override
  void initState() {
    super.initState();
    selectedDay = _getCurrentDay();
    _loadSelectedPlanExercises();
  }

  String _getCurrentDay() {
    List<String> days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return days[DateTime.now().weekday % 7];
  }

  Future<void> _loadSelectedPlanExercises() async {
    try {
      if (widget.selectedPlanId == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final planDoc = await _firestore
          .collection('workout_plans')
          .doc(widget.selectedPlanId)
          .get();

      if (!planDoc.exists) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final planData = planDoc.data() as Map<String, dynamic>;
      final rawExercises = planData['exercises'] as Map<String, dynamic>? ?? {};

      Map<String, List<Map<String, dynamic>>> processedExercises = {};

      rawExercises.forEach((day, exercises) {
        if (exercises is List) {
          processedExercises[day] = exercises.map((e) {
            final exerciseData = e['exerciseData'] as Map<String, dynamic>;
            return {
              'name': e['name'],
              'sets': e['sets'],
              'reps': e['reps'],
              'restTime': e['restTime'],
              'instructions': exerciseData['instructions'],
              'primaryMuscles': exerciseData['primaryMuscles'],
              'secondaryMuscles': exerciseData['secondaryMuscles'],
              'equipment': exerciseData['equipment'],
              'level': exerciseData['level'],
              'images': exerciseData['images'],
            };
          }).toList();
        }
      });

      setState(() {
        planName = planData['name'] ?? "Workout Plan";
        exercisesByDay = processedExercises;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading exercises: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isLoading = false;
      });
    }
  }

  bool _containsMuscleInCategory(List<dynamic> primary,
      List<dynamic>? secondary, List<String> categoryMuscles) {
    for (final muscle in categoryMuscles) {
      if (primary.contains(muscle) || (secondary ?? []).contains(muscle)) {
        return true;
      }
    }
    return false;
  }

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

  Widget _buildMuscleCategories(Map<String, bool> categories) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: categories.entries.where((e) => e.value).map((entry) {
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
                size: 12,
                color: _getMuscleColor(entry.key),
              ),
              SizedBox(width: 3),
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 11,
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

  Map<String, bool> _categorizeMusclesForExercise(
      Map<String, dynamic> exercise) {
    final primaryMuscles = exercise['primaryMuscles'] as List<dynamic>? ?? [];
    final secondaryMuscles =
        exercise['secondaryMuscles'] as List<dynamic>? ?? [];

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

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.sizeOf(context);
    final todaysExercises = exercisesByDay[selectedDay] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColor.primary,
        centerTitle: true,
        elevation: 0.1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon:
              Image.asset("assets/img/black_white.png", width: 25, height: 25),
        ),
        title: Text(
          "$planName - $selectedDay",
          style: TextStyle(
            color: TColor.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 60,
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
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                final List<String> days = [
                  "Mon",
                  "Tue",
                  "Wed",
                  "Thu",
                  "Fri",
                  "Sat",
                  "Sun"
                ];
                final day = days[index];
                final isSelected = selectedDay == day;

                return Container(
                  width: media.width / 7,
                  child: InkWell(
                    onTap: () => setState(() => selectedDay = day),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected
                                ? TColor.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day,
                            style: TextStyle(
                              color: isSelected
                                  ? TColor.primary
                                  : TColor.secondaryText,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              margin: EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: TColor.primary,
                                shape: BoxShape.circle,
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
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : todaysExercises.isEmpty
                    ? Container(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: TColor.white,
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
                                  Icon(
                                    Icons.self_improvement,
                                    size: 80,
                                    color: TColor.primary,
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    "Rest Day",
                                    style: TextStyle(
                                      color: TColor.primary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "No exercises scheduled for $selectedDay.\nTake this time to rest and recover.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: TColor.secondaryText,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    "Remember:",
                                    style: TextStyle(
                                      color: TColor.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "• Rest is essential for muscle recovery\n• Stay hydrated\n• Get adequate sleep\n• Light stretching is beneficial",
                                    style: TextStyle(
                                      color: TColor.secondaryText,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: CarouselSlider.builder(
                              options: CarouselOptions(
                                height: media.width * 1.1,
                                autoPlay: false,
                                aspectRatio: 0.85,
                                enlargeCenterPage: true,
                                viewportFraction: 0.85,
                                enableInfiniteScroll: false,
                                onPageChanged: (index, reason) {
                                  setState(() {
                                    _currentExerciseIndex = index;
                                  });
                                },
                              ),
                              itemCount: todaysExercises.length,
                              itemBuilder: (context, index, realIndex) {
                                final exercise = todaysExercises[index];
                                final muscleCategories =
                                    _categorizeMusclesForExercise(exercise);

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 10),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: TColor.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              exercise["name"] ?? "Exercise",
                                              style: TextStyle(
                                                color: TColor.primary,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: TColor.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              "${index + 1}/${todaysExercises.length}",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "Sets: ${exercise["sets"]} × Reps: ${exercise["reps"]}",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        "Rest: ${exercise["restTime"]} seconds",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: TColor.secondaryText,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      _buildMuscleCategories(muscleCategories),
                                      SizedBox(height: 10),
                                      Text(
                                        "Instructions:",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView(
                                          children: (exercise["instructions"]
                                                      as List?)
                                                  ?.map((instruction) =>
                                                      Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                vertical: 4),
                                                        child: Text(
                                                          "• $instruction",
                                                          style: TextStyle(
                                                              fontSize: 14),
                                                        ),
                                                      ))
                                                  .toList() ??
                                              [],
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Center(
                                        child: SizedBox(
                                          width: 200,
                                          child: RoundButton(
                                            title: "Start Exercise",
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ExerciseExecutionView(
                                                    exercises: todaysExercises,
                                                    currentExerciseIndex:
                                                        _currentExerciseIndex,
                                                    userId: widget.userId,
                                                    workoutPlanName: planName,
                                                    workoutPlanId:
                                                        widget.selectedPlanId ??
                                                            '',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (todaysExercises.length > 1)
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  todaysExercises.length,
                                  (index) => Container(
                                    width: 8,
                                    height: 8,
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentExerciseIndex == index
                                          ? TColor.primary
                                          : TColor.primary.withOpacity(0.3),
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
}
