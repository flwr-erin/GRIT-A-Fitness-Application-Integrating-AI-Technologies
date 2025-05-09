import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../common/color_extension.dart';
import '../common/exercise_detail_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseSelectionView extends StatefulWidget {
  final Function(Map<String, dynamic>, int, int) onExerciseSelected;
  final String username; // Add username parameter

  const ExerciseSelectionView({
    Key? key,
    required this.onExerciseSelected,
    required this.username, // Add this line
  }) : super(key: key);

  @override
  State<ExerciseSelectionView> createState() => _ExerciseSelectionViewState();
}

class _ExerciseSelectionViewState extends State<ExerciseSelectionView> {
  List<Map<String, dynamic>> exercises = [];
  List<Map<String, dynamic>> filteredExercises = [];
  TextEditingController searchController = TextEditingController();
  bool isRecommended = true;
  int fitnessLevel = 0; // Add this line as default value

  // Add muscle category filter
  Map<String, bool> selectedMuscleCategories = {
    'CHEST': false,
    'BACK': false,
    'ARMS': false,
    'ABDOMINALS': false,
    'LEGS': false,
    'SHOULDERS': false,
  };

  bool isFilteringByMuscle = false;

  @override
  void initState() {
    super.initState();
    loadExercises();
    _loadUserFitnessLevel();

    // Add listener for fitness level changes
    _setupFitnessLevelListener();
  }

  // Add this method to listen for fitness level updates
  void _setupFitnessLevelListener() {
    if (widget.username.isEmpty) return;

    FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(widget.username)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('fitnessLevel')) {
          int newFitnessLevel = data['fitnessLevel'] ?? 0;

          if (newFitnessLevel != fitnessLevel) {
            setState(() {
              fitnessLevel = newFitnessLevel;
              // Refresh filtered exercises to update recommendations
              if (isRecommended) {
                filteredExercises = getFilteredExercises();
              }
            });

            print(
                'ExerciseSelectionView: Fitness level updated to: $fitnessLevel');
          }
        }
      }
    });
  }

  Future<void> loadExercises() async {
    final String response =
        await rootBundle.loadString('assets/json/exercises.json');
    final List<dynamic> data = json.decode(response);
    setState(() {
      exercises = List<Map<String, dynamic>>.from(data);
      filteredExercises = exercises;
    });
  }

  String _sanitizeUsername(String username) {
    // Remove whitespace and special characters
    return username.trim().replaceAll(RegExp(r'[^\w\s]+'), '');
  }

  Future<void> _loadUserFitnessLevel() async {
    try {
      final String sanitizedUsername = _sanitizeUsername(widget.username);
      print('Loading fitness level for username: $sanitizedUsername');

      // Get user profile directly from root level collection
      final profileDoc = await FirebaseFirestore.instance
          .collection('user_profiles') // Changed from nested structure
          .doc(sanitizedUsername)
          .get();

      print('Profile document exists: ${profileDoc.exists}');

      if (profileDoc.exists) {
        final profileData = profileDoc.data()!;
        setState(() {
          fitnessLevel = profileData['fitnessLevel'] ?? 0;
          // Refresh filtered exercises
          if (isRecommended) {
            filteredExercises = getFilteredExercises();
          }
        });
        print('Successfully loaded fitness level: $fitnessLevel');
      } else {
        print('No profile found for username: $sanitizedUsername');
        setState(() => fitnessLevel = 0);
      }
    } catch (e) {
      print('Error in _loadUserFitnessLevel: $e');
      setState(() => fitnessLevel = 0);
    }
  }

  String _getLevelByFitnessLevel() {
    switch (fitnessLevel) {
      // Use class variable instead of widget parameter
      case 0:
        return 'beginner';
      case 1:
        return 'intermediate';
      case 2:
        return 'expert';
      default:
        return 'beginner';
    }
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

  // New method to check if exercise matches selected muscle filters
  bool _exerciseMatchesMuscleFilters(Map<String, dynamic> exercise) {
    // If no muscle filters are selected, return true
    if (!selectedMuscleCategories.containsValue(true)) {
      return true;
    }

    List<dynamic> primaryMuscles = exercise['primaryMuscles'] ?? [];
    List<dynamic> secondaryMuscles = exercise['secondaryMuscles'] ?? [];

    // Check each selected muscle category
    if (selectedMuscleCategories['CHEST'] == true &&
        _containsMuscleInCategory(
            primaryMuscles, secondaryMuscles, ['chest'])) {
      return true;
    }

    if (selectedMuscleCategories['BACK'] == true &&
        _containsMuscleInCategory(primaryMuscles, secondaryMuscles,
            ['middle back', 'lower back', 'lats', 'traps', 'neck'])) {
      return true;
    }

    if (selectedMuscleCategories['ARMS'] == true &&
        _containsMuscleInCategory(primaryMuscles, secondaryMuscles,
            ['biceps', 'triceps', 'forearms'])) {
      return true;
    }

    if (selectedMuscleCategories['ABDOMINALS'] == true &&
        _containsMuscleInCategory(
            primaryMuscles, secondaryMuscles, ['abdominals'])) {
      return true;
    }

    if (selectedMuscleCategories['LEGS'] == true &&
        _containsMuscleInCategory(primaryMuscles, secondaryMuscles, [
          'hamstrings',
          'abductors',
          'quadriceps',
          'calves',
          'glutes',
          'adductors'
        ])) {
      return true;
    }

    if (selectedMuscleCategories['SHOULDERS'] == true &&
        _containsMuscleInCategory(
            primaryMuscles, secondaryMuscles, ['shoulders'])) {
      return true;
    }

    return false;
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

  List<Map<String, dynamic>> getFilteredExercises() {
    var filtered = isRecommended
        ? exercises.where((e) {
            bool matchesFitnessLevel = e['level'] == _getLevelByFitnessLevel();
            bool hasInstructions = (e['instructions'] as List).isNotEmpty;
            bool hasImages = (e['images'] as List).isNotEmpty;
            return matchesFitnessLevel && hasInstructions && hasImages;
          }).toList()
        : exercises;

    // Apply search filter
    if (searchController.text.isNotEmpty) {
      filtered = filtered
          .where((e) => e['name']
              .toString()
              .toLowerCase()
              .contains(searchController.text.toLowerCase()))
          .toList();
    }

    // Apply muscle category filter if any are selected
    if (isFilteringByMuscle) {
      filtered = filtered.where(_exerciseMatchesMuscleFilters).toList();
    }

    return filtered;
  }

  void _showMuscleFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter by Muscle Group',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: TColor.primary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: selectedMuscleCategories.keys.map((category) {
                      bool isSelected = selectedMuscleCategories[category]!;
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getMuscleIcon(category),
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : _getMuscleColor(category),
                            ),
                            SizedBox(width: 5),
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : _getMuscleColor(category),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (value) {
                          setModalState(() {
                            selectedMuscleCategories[category] = value;
                          });
                        },
                        selectedColor: _getMuscleColor(category),
                        backgroundColor:
                            _getMuscleColor(category).withOpacity(0.1),
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _getMuscleColor(category),
                            width: 1,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          setModalState(() {
                            selectedMuscleCategories
                                .updateAll((key, value) => false);
                          });
                        },
                        child: Text('Clear All'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColor.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          // Check if any filter is selected
                          bool anyFilterSelected =
                              selectedMuscleCategories.values.contains(true);

                          setState(() {
                            isFilteringByMuscle = anyFilterSelected;
                          });

                          Navigator.pop(context);
                        },
                        child: Text('Apply Filter'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSetsRepsDialog(Map<String, dynamic> exercise) {
    int? sets;
    int? reps;
    int? restTime;

    // Create TextEditingControllers with empty values
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final restTimeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TColor.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text(
          'Set Exercise Details',
          style: TextStyle(
            color: TColor.primary,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exercise: ${exercise['name']}',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 16,
                color: TColor.gray,
              ),
            ),
            SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: TColor.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Sets',
                      hintText: 'Enter number of sets',
                      labelStyle: TextStyle(color: TColor.gray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: TColor.primary),
                      ),
                    ),
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        sets = int.tryParse(value);
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Reps',
                      hintText: 'Enter number of reps',
                      labelStyle: TextStyle(color: TColor.gray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: TColor.primary),
                      ),
                    ),
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        reps = int.tryParse(value);
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Rest Time (seconds)',
                      hintText: 'Enter rest time in seconds',
                      labelStyle: TextStyle(color: TColor.gray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: TColor.primary),
                      ),
                    ),
                    controller: restTimeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        restTime = int.tryParse(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: TColor.gray,
            ),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Quicksand'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Check if the values are set
              if (sets == null || reps == null || restTime == null) {
                // Show error if any field is empty
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Add rest time to the exercise data
              exercise['restTime'] = restTime;
              widget.onExerciseSelected(exercise, sets!, reps!);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Add',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build muscle category indicator for each exercise
  Widget _buildMuscleCategories(Map<String, dynamic> exercise) {
    List<dynamic> primaryMuscles = exercise['primaryMuscles'] ?? [];
    List<dynamic> secondaryMuscles = exercise['secondaryMuscles'] ?? [];

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

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: muscleCategories.entries.where((e) => e.value).map((entry) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.primary,
        title: TextField(
          controller: searchController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search exercises...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.white70),
          ),
          onChanged: (value) => setState(() {}),
        ),
        actions: [
          // Add filter button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.filter_list),
                onPressed: _showMuscleFilterBottomSheet,
              ),
              if (isFilteringByMuscle)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Container(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => isRecommended = true),
                    child: Container(
                      color:
                          isRecommended ? TColor.primary : Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        'For You',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isRecommended
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => isRecommended = false),
                    child: Container(
                      color:
                          !isRecommended ? TColor.primary : Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        'All Exercises',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: !isRecommended
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Show filter indicator when filtering by muscles
          if (isFilteringByMuscle)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.amber.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: Colors.amber[800]),
                  SizedBox(width: 8),
                  Text(
                    'Filtering by muscle groups',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedMuscleCategories
                            .updateAll((key, value) => false);
                        isFilteringByMuscle = false;
                      });
                    },
                    child: Text('Clear',
                        style: TextStyle(color: Colors.amber[800])),
                  ),
                ],
              ),
            ),
          Expanded(
            child: getFilteredExercises().isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 70,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "No exercises found",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Try adjusting your filters or search term",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(15),
                    itemCount: getFilteredExercises().length,
                    itemBuilder: (context, index) {
                      final exercise = getFilteredExercises()[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 15),
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(15)),
                                  child: Image.asset(
                                    'assets/json/img/${exercise['images'][0]}',
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 80,
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
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  // Add muscle categories indicator
                                  _buildMuscleCategories(exercise),
                                  SizedBox(height: 8),
                                  Container(
                                    height: 100,
                                    child: Stack(
                                      children: [
                                        Text(
                                          exercise['instructions'].join(' '),
                                          style: TextStyle(
                                            fontFamily: 'Quicksand',
                                            color: Colors.grey[600],
                                            height: 1.5,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 60,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.white,
                                                  Colors.white.withOpacity(0.9),
                                                  Colors.white.withOpacity(0.3),
                                                  Colors.white.withOpacity(0),
                                                ],
                                                stops: [0.0, 0.3, 0.7, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showSetsRepsDialog(exercise),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: TColor.primary,
                                          foregroundColor: TColor.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: Text(
                                          'Add Exercise',
                                          style: TextStyle(
                                            fontFamily: 'Quicksand',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
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
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey,
                                          foregroundColor: TColor.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: Text(
                                          'View More',
                                          style: TextStyle(
                                            fontFamily: 'Quicksand',
                                            fontWeight: FontWeight.bold,
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
