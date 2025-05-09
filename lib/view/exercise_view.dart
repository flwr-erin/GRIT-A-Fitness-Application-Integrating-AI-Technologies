import 'dart:convert';
import 'package:fitness_app/common/exercise_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/color_extension.dart';

class ExerciseView extends StatefulWidget {
  final String username; // Add this line
  const ExerciseView({super.key, required this.username}); // Update constructor

  @override
  State<ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List exercises = [];
  List filteredExercises = [];
  List forYouExercises = [];
  String userFitnessLevel = 'beginner'; // default value
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  // Add new filter variables
  String? selectedCategory;
  String? selectedForce;
  String? selectedLevel;
  String? selectedMechanic;
  String? selectedEquipment;
  String? selectedPrimaryMuscle;
  String? selectedSecondaryMuscle;

  // Add sets for filter options
  Set<String> categories = {};
  Set<String> forces = {};
  Set<String> levels = {};
  Set<String> mechanics = {};
  Set<String> equipment = {};
  Set<String> primaryMuscles = {};
  Set<String> secondaryMuscles = {};

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
    loadExercises();
    _searchController.addListener(_filterExercises);
    _loadUserFitnessLevel();

    // Add listener for fitness level changes
    _setupFitnessLevelListener();

    // Add scroll listener
    _scrollController.addListener(() {
      if (_scrollController.offset >= 400) {
        setState(() {
          _showBackToTop = true;
        });
      } else {
        setState(() {
          _showBackToTop = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose(); // Add this line
    super.dispose();
  }

  Future<void> loadExercises() async {
    String data = await DefaultAssetBundle.of(context)
        .loadString('assets/json/exercises.json');
    List jsonResult = json.decode(data);
    setState(() {
      exercises = jsonResult;
      filteredExercises = jsonResult;

      // Extract unique values for each filter
      categories = _extractUniqueValues(exercises, 'category');
      forces = _extractUniqueValues(exercises, 'force');
      levels = _extractUniqueValues(exercises, 'level');
      mechanics = _extractUniqueValues(exercises, 'mechanic');
      equipment = _extractUniqueValues(exercises, 'equipment');
      primaryMuscles =
          _extractUniqueValues(exercises, 'primaryMuscles', isList: true);
      secondaryMuscles =
          _extractUniqueValues(exercises, 'secondaryMuscles', isList: true);
    });
  }

  Set<String> _extractUniqueValues(List items, String key,
      {bool isList = false}) {
    Set<String> values = {};
    for (var item in items) {
      if (isList) {
        if (item[key] != null) {
          values.addAll(List<String>.from(item[key]));
        }
      } else {
        if (item[key] != null) {
          values.add(item[key].toString());
        }
      }
    }
    return values;
  }

  void _filterExercises() {
    setState(() {
      filteredExercises = exercises.where((exercise) {
        // Search text filter
        bool matchesSearch = exercise['name']
            .toString()
            .toLowerCase()
            .contains(_searchController.text.toLowerCase());

        // Category filter
        bool matchesCategory = selectedCategory == null ||
            exercise['category'] == selectedCategory;

        // Force filter
        bool matchesForce =
            selectedForce == null || exercise['force'] == selectedForce;

        // Level filter
        bool matchesLevel =
            selectedLevel == null || exercise['level'] == selectedLevel;

        // Mechanic filter
        bool matchesMechanic = selectedMechanic == null ||
            exercise['mechanic'] == selectedMechanic;

        // Equipment filter
        bool matchesEquipment = selectedEquipment == null ||
            exercise['equipment'] == selectedEquipment;

        // Primary muscle filter
        bool matchesPrimaryMuscle = selectedPrimaryMuscle == null ||
            (exercise['primaryMuscles'] as List)
                .contains(selectedPrimaryMuscle);

        // Secondary muscle filter
        bool matchesSecondaryMuscle = selectedSecondaryMuscle == null ||
            (exercise['secondaryMuscles'] as List)
                .contains(selectedSecondaryMuscle);

        return matchesSearch &&
            matchesCategory &&
            matchesForce &&
            matchesLevel &&
            matchesMechanic &&
            matchesEquipment &&
            matchesPrimaryMuscle &&
            matchesSecondaryMuscle;
      }).toList();

      // After filtering exercises, also update forYouExercises with the same filters
      _filterForYouExercises();
    });
  }

  void _filterForYouExercises() {
    setState(() {
      // First filter by user's fitness level
      forYouExercises = exercises.where((exercise) {
        return exercise['level'].toString().toLowerCase() == userFitnessLevel;
      }).toList();

      // Then apply all other filters to forYouExercises
      if (_searchController.text.isNotEmpty ||
          selectedCategory != null ||
          selectedForce != null ||
          selectedLevel != null ||
          selectedMechanic != null ||
          selectedEquipment != null ||
          selectedPrimaryMuscle != null ||
          selectedSecondaryMuscle != null) {
        forYouExercises = forYouExercises.where((exercise) {
          // Search text filter
          bool matchesSearch = exercise['name']
              .toString()
              .toLowerCase()
              .contains(_searchController.text.toLowerCase());

          // Category filter
          bool matchesCategory = selectedCategory == null ||
              exercise['category'] == selectedCategory;

          // Force filter
          bool matchesForce =
              selectedForce == null || exercise['force'] == selectedForce;

          // Level filter
          bool matchesLevel =
              selectedLevel == null || exercise['level'] == selectedLevel;

          // Mechanic filter
          bool matchesMechanic = selectedMechanic == null ||
              exercise['mechanic'] == selectedMechanic;

          // Equipment filter
          bool matchesEquipment = selectedEquipment == null ||
              exercise['equipment'] == selectedEquipment;

          // Primary muscle filter
          bool matchesPrimaryMuscle = selectedPrimaryMuscle == null ||
              (exercise['primaryMuscles'] as List)
                  .contains(selectedPrimaryMuscle);

          // Secondary muscle filter
          bool matchesSecondaryMuscle = selectedSecondaryMuscle == null ||
              (exercise['secondaryMuscles'] as List)
                  .contains(selectedSecondaryMuscle);

          return matchesSearch &&
              matchesCategory &&
              matchesForce &&
              matchesLevel &&
              matchesMechanic &&
              matchesEquipment &&
              matchesPrimaryMuscle &&
              matchesSecondaryMuscle;
        }).toList();
      }
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Make the bottom sheet full height
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: TColor.gray,
                      fontFamily: 'Quicksand',
                    )),
                SizedBox(height: 20),
                _buildFilterSection(
                    'Category',
                    categories,
                    selectedCategory,
                    (value) => setState(() {
                          selectedCategory = value;
                          _filterExercises();
                        })),
                _buildFilterSection(
                    'Force',
                    forces,
                    selectedForce,
                    (value) => setState(() {
                          selectedForce = value;
                          _filterExercises();
                        })),
                _buildFilterSection(
                    'Level',
                    levels,
                    selectedLevel,
                    (value) => setState(() {
                          selectedLevel = value;
                          _filterExercises();
                        })),
                _buildFilterSection(
                    'Mechanic',
                    mechanics,
                    selectedMechanic,
                    (value) => setState(() {
                          selectedMechanic = value;
                          _filterExercises();
                        })),
                _buildFilterSection(
                    'Equipment',
                    equipment,
                    selectedEquipment,
                    (value) => setState(() {
                          selectedEquipment = value;
                          _filterExercises();
                        })),
                _buildFilterSection(
                    'Primary Muscle',
                    primaryMuscles,
                    selectedPrimaryMuscle,
                    (value) => setState(() {
                          selectedPrimaryMuscle = value;
                          _filterExercises();
                        })),
                _buildFilterSection(
                    'Secondary Muscle',
                    secondaryMuscles,
                    selectedSecondaryMuscle,
                    (value) => setState(() {
                          selectedSecondaryMuscle = value;
                          _filterExercises();
                        })),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCategory = null;
                      selectedForce = null;
                      selectedLevel = null;
                      selectedMechanic = null;
                      selectedEquipment = null;
                      selectedPrimaryMuscle = null;
                      selectedSecondaryMuscle = null;
                      _filterExercises();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColor.primary,
                    foregroundColor: TColor.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Clear All Filters',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Set<String> options,
      String? selectedValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: TColor.gray,
              fontFamily: 'Quicksand',
            )),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Text('All'),
              selected: selectedValue == null,
              selectedColor: TColor.primary.withOpacity(0.2),
              checkmarkColor: TColor.primary,
              labelStyle: TextStyle(
                color: selectedValue == null ? TColor.primary : TColor.gray,
                fontFamily: 'Quicksand',
              ),
              onSelected: (bool selected) {
                if (selected) {
                  onChanged(null);
                }
              },
            ),
            ...options.map((option) => FilterChip(
                  label: Text(option),
                  selected: selectedValue == option,
                  selectedColor: TColor.primary.withOpacity(0.2),
                  checkmarkColor: TColor.primary,
                  labelStyle: TextStyle(
                    color:
                        selectedValue == option ? TColor.primary : TColor.gray,
                    fontFamily: 'Quicksand',
                  ),
                  onSelected: (bool selected) {
                    onChanged(selected ? option : null);
                  },
                )),
          ],
        ),
        SizedBox(height: 20),
      ],
    );
  }

  // Add this method
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadUserFitnessLevel() async {
    final fitnessLevels = {0: 'beginner', 1: 'intermediate', 2: 'expert'};
    try {
      print('Loading fitness level for user: ${widget.username}');
      if (widget.username.isEmpty) {
        print('Error: Username is empty');
        return;
      }

      // Changed to use root-level user_profiles collection
      final userProfileDoc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(widget.username)
          .get();

      print('Document exists: ${userProfileDoc.exists}');
      if (userProfileDoc.exists) {
        print('User data: ${userProfileDoc.data()}');
        int fitnessLevelValue = userProfileDoc.data()?['fitnessLevel'] ?? 0;

        String newLevel;
        switch (fitnessLevelValue) {
          case 0:
            newLevel = 'beginner';
            break;
          case 1:
            newLevel = 'intermediate';
            break;
          case 2:
            newLevel = 'expert';
            break;
          default:
            newLevel = 'beginner';
        }

        setState(() {
          userFitnessLevel = newLevel;
          _filterForYouExercises();
        });
        print('ExerciseView: Fitness level loaded: $userFitnessLevel');
      } else {
        print('Creating default profile for user: ${widget.username}');
        // Create default profile in root-level user_profiles collection
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(widget.username)
            .set({
          'fitnessLevel': 0,
          'username': widget.username,
          // Add other default profile fields as needed
        });
        setState(() {
          userFitnessLevel = fitnessLevels[0]!;
          _filterForYouExercises();
        });
      }
    } catch (e, stackTrace) {
      print('Error loading fitness level: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        userFitnessLevel = fitnessLevels[0]!;
        _filterForYouExercises();
      });
    }
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
          int fitnessLevelValue = data['fitnessLevel'] ?? 0;
          String newLevel;

          switch (fitnessLevelValue) {
            case 0:
              newLevel = 'beginner';
              break;
            case 1:
              newLevel = 'intermediate';
              break;
            case 2:
              newLevel = 'expert';
              break;
            default:
              newLevel = 'beginner';
          }

          if (newLevel != userFitnessLevel) {
            setState(() {
              userFitnessLevel = newLevel;
            });

            // Refresh for you exercises
            _filterForYouExercises();
            print('ExerciseView: Fitness level updated to: $userFitnessLevel');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TColor.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: TColor.primary,
        centerTitle: false,
        elevation: 0.1,
        title: Container(
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            color: TColor.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: TColor.gray, fontFamily: 'Quicksand'),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: TColor.gray),
                hintText: 'Search exercises...',
                hintStyle:
                    TextStyle(color: TColor.gray, fontFamily: 'Quicksand'),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TColor.white,
          tabs: [
            Tab(
              child: Text(
                'For You',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Tab(
              child: Text(
                'Exercises',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // For You Tab
          Stack(
            children: [
              forYouExercises.isEmpty
                  ? Center(
                      child: Text(
                        'Loading personalized exercises...',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 16,
                          color: TColor.gray,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController, // Add scroll controller
                      padding: EdgeInsets.all(15),
                      itemCount: forYouExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = forYouExercises[index];
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
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: TColor.primary.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        'Recommended',
                                        style: TextStyle(
                                          color: TColor.white,
                                          fontFamily: 'Quicksand',
                                          fontWeight: FontWeight.bold,
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
                                    SizedBox(height: 12),
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
                                                    Colors.white
                                                        .withOpacity(0.9),
                                                    Colors.white
                                                        .withOpacity(0.3),
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
                                    Center(
                                      child: ElevatedButton(
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
                                          'View More',
                                          style: TextStyle(
                                            fontFamily: 'Quicksand',
                                            fontWeight: FontWeight.bold,
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
                      },
                    ),
              if (_showBackToTop)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: _scrollToTop,
                    backgroundColor: TColor.primary.withOpacity(0.7),
                    mini: true, // Makes the FAB smaller
                    elevation: 4,
                    child: Icon(Icons.arrow_upward, size: 20),
                  ),
                ),
            ],
          ),
          // Exercises Tab (Original Content)
          Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(15),
                itemCount: filteredExercises.length,
                itemBuilder: (context, index) {
                  final exercise = filteredExercises[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 15),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image with gradient overlay
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
                              SizedBox(height: 12),
                              // Modified instructions container with continuous text
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
                              // View More button
                              Center(
                                child: ElevatedButton(
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
                                    backgroundColor: TColor.primary,
                                    foregroundColor: TColor.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_showBackToTop)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: _scrollToTop,
                    backgroundColor: TColor.primary.withOpacity(0.7),
                    mini: true, // Makes the FAB smaller
                    elevation: 4,
                    child: Icon(Icons.arrow_upward, size: 20),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
