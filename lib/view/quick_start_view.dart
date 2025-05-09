import 'package:fitness_app/models/jumping_jack_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for input formatters
import '../../common/color_extension.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/push_up_model.dart';
import '../pose estimation/pose_detection_view.dart';
import '../models/squat_model.dart';
import 'package:fitness_app/models/pull_up_model.dart';
import 'package:fitness_app/models/sit_up_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Exercise {
  final String name;
  final String instructions;
  int sets;
  int reps;
  int restTime;
  final IconData? icon; // Make icon optional with ?

  Exercise({
    required this.name,
    required this.instructions,
    this.sets = 0,
    this.reps = 0,
    this.restTime = 0,
    this.icon, // Remove required
  });
}

class QuickStartView extends StatefulWidget {
  const QuickStartView({super.key});

  @override
  State<QuickStartView> createState() => _QuickStartViewState();
}

class _QuickStartViewState extends State<QuickStartView>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? username;
  String? userId;
  bool _isLoading = true;
  bool _showHistory = false;
  List<Map<String, dynamic>> exerciseHistory = [];

  final List<Exercise> exercises = [
    Exercise(
      name: 'Push Ups',
      instructions:
          '1. Start in a plank position, hands slightly wider than shoulders\n'
          '2. Keep your body in a straight line from head to heels\n'
          '3. Lower your body until chest nearly touches the ground\n'
          '4. Push back up to starting position\n'
          '5. Keep your core tight throughout the movement\n\n'
          'For Best Detection:\n'
          '• Position your phone to your right side\n'
          '• Ensure your full body is visible in the frame\n'
          '• Wear contrasting colors to your background\n'
          '• Make sure the area is well lit',
      icon: Icons.front_hand, // Updated icon for push ups
    ),
    Exercise(
      name: 'Pull Ups',
      instructions: '1. Hang from bar with palms facing away\n'
          '2. Keep your arms straight at the starting position\n'
          '3. Pull yourself up until chin is above the bar\n'
          '4. Lower back down with control\n'
          '5. Maintain a steady rhythm\n\n'
          'For Best Detection:\n'
          '• Position camera to your front\n'
          '• Ensure full body is visible\n'
          '• Make sure area is well lit\n'
          '• Keep 6-8 feet distance from phone',
      icon: Icons.arrow_upward, // Updated icon for pull ups
    ),
    Exercise(
      name: 'Sit Ups',
      instructions: '1. Lie on your back with knees bent\n'
          '2. Place hands behind your head\n'
          '3. Keep elbows wide\n'
          '4. Lift upper body toward knees\n'
          '5. Lower back with control\n\n'
          'For Best Detection:\n'
          '• Position camera to your left side\n'
          '• Ensure full body is visible\n'
          '• Keep 6-8 feet distance from phone\n'
          '• Use a mat for comfort',
      icon: Icons.sync_alt, // Updated icon for sit ups
    ),
    Exercise(
      name: 'Squat',
      instructions: '1. Stand with feet shoulder-width apart\n'
          '2. Keep chest up and back straight\n'
          '3. Lower your body as if sitting back into a chair\n'
          '4. Keep knees in line with toes\n'
          '5. Push through heels to return to standing\n\n'
          'For Best Detection:\n'
          '• Stand sideways to the camera\n'
          '• Keep 6-8 feet distance from phone\n'
          '• Ensure entire body is visible',
      icon: Icons.keyboard_double_arrow_down, // Updated icon for squats
    ),
    Exercise(
      name: 'Jumping Jacks',
      instructions: '1. Stand upright with feet together and arms at sides\n'
          '2. Jump and spread legs while raising arms above head\n'
          '3. Jump back to starting position\n'
          '4. Land softly and immediately repeat\n'
          '5. Keep a steady rhythm\n\n'
          'For Best Detection:\n'
          '• Face the camera directly\n'
          '• Stay 6-8 feet away from the phone\n'
          '• Ensure your full body is visible\n'
          '• Avoid loose or baggy clothing',
      icon: Icons.directions_run, // Kept the running icon for jumping jacks
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedUsername = prefs.getString('username');

      if (storedUsername != null) {
        // Get user ID from username
        final QuerySnapshot userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: storedUsername)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          setState(() {
            username = storedUsername;
            userId = userQuery.docs.first.id;
            _isLoading = false;
          });

          // Load exercise history
          await _loadExerciseHistory();
        } else {
          setState(() {
            _isLoading = false;
          });
          print('User not found for username: $storedUsername');
        }
      } else {
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

  Future<void> _loadExerciseHistory() async {
    if (userId == null) return;

    try {
      print("Loading exercise history for user: $userId");
      final QuerySnapshot historySnapshot = await _firestore
          .collection('pose_exercise_history')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      print("Found ${historySnapshot.docs.length} history records");
      final List<Map<String, dynamic>> history = [];

      for (var doc in historySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        history.add({
          'id': doc.id,
          ...data,
        });
        print("Loaded history record: ${data['exerciseName']}");
      }

      setState(() {
        exerciseHistory = history;
      });

      print('Loaded ${history.length} exercise history records');
    } catch (e, stackTrace) {
      print('Error loading exercise history: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _saveExerciseToDatabase(String exerciseName, int sets, int reps,
      int restTime, int completedSets, int completedReps) async {
    if (userId == null) {
      print('Cannot save exercise: userId is null');
      return;
    }

    try {
      // Create the exercise record
      await _firestore.collection('pose_exercise_history').add({
        'userId': userId,
        'username': username,
        'exerciseName': exerciseName,
        'targetSets': sets,
        'targetReps': reps,
        'restTime': restTime,
        'completedSets': completedSets,
        'completedReps': completedReps,
        'completion': completedSets / sets * 100,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Exercise saved successfully: $exerciseName');

      // Reload history after saving
      await _loadExerciseHistory();
    } catch (e) {
      print('Error saving exercise: $e');
    }
  }

  // Helper method to get the appropriate GIF path for each exercise
  String _getExerciseGifPath(String exerciseName) {
    switch (exerciseName) {
      case 'Push Ups':
        return 'assets/gif/push ups.gif';
      case 'Pull Ups':
        return 'assets/gif/pull ups.gif';
      case 'Sit Ups':
        return 'assets/gif/sit ups.gif';
      case 'Squat':
        return 'assets/gif/squats.gif';
      case 'Jumping Jacks':
        return 'assets/gif/jumping jacks.gif';
      default:
        return 'assets/gif/workout.gif'; // Default GIF
    }
  }

  // Helper method to determine the proper BoxFit for each exercise
  BoxFit _getExerciseImageFit(String exerciseName) {
    switch (exerciseName) {
      case 'Squat':
      case 'Pull Ups':
      case 'Jumping Jacks':
        return BoxFit.contain; // Use contain to ensure the full image is shown
      default:
        return BoxFit.cover; // Cover for other exercises
    }
  }

  // Helper method to get the appropriate sizing for each exercise image
  Widget _getExerciseImage(String exerciseName, String gifPath) {
    switch (exerciseName) {
      case 'Squat':
      case 'Pull Ups':
      case 'Jumping Jacks':
        return Container(
          padding: EdgeInsets.all(10),
          child: Image.asset(
            gifPath,
            fit: BoxFit.contain,
          ),
        );
      default:
        return Image.asset(
          gifPath,
          fit: BoxFit.cover,
        );
    }
  }

  // Extract the "For Best Detection" part from instructions
  String _getDetectionInstructions(String instructions) {
    if (instructions.contains('For Best Detection:')) {
      return instructions.split('For Best Detection:')[1].trim();
    }
    return '';
  }

  // Extract the exercise instructions (without the detection part)
  String _getExerciseInstructions(String instructions) {
    if (instructions.contains('For Best Detection:')) {
      return instructions.split('For Best Detection:')[0].trim();
    }
    return instructions;
  }

  // Show detailed exercise instructions dialog
  void _showInstructionsDialog(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${exercise.name} Form Guide',
              style: TextStyle(
                color: TColor.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: TColor.primary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: TColor.primary.withOpacity(0.3), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: _getExerciseImage(
                    exercise.name,
                    _getExerciseGifPath(exercise.name),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Proper Form Instructions',
                style: TextStyle(
                  color: TColor.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              ...(_getExerciseInstructions(exercise.instructions)
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)
                  .map((instruction) {
                if (instruction.contains('.')) {
                  final parts = instruction.split('.');
                  if (parts.length > 1 && parts[0].trim().length <= 2) {
                    // This is a numbered instruction
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TColor.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              parts[0].trim(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              parts.sublist(1).join('.').trim(),
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    instruction,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                );
              }).toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: TColor.primary, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showExerciseDialog(Exercise exercise) {
    // Create local state variables to track the input values
    TextEditingController setsController = TextEditingController();
    TextEditingController repsController = TextEditingController();
    TextEditingController restTimeController = TextEditingController();

    int sets = 0;
    int reps = 0;
    int restTime = 0;

    // Extract detection instructions
    String detectionInstructions =
        _getDetectionInstructions(exercise.instructions);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exercise.name,
                style: TextStyle(
                  color: TColor.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: TColor.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exercise GIF with info icon overlay
                Stack(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: TColor.primary.withOpacity(0.3), width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: _getExerciseImage(
                          exercise.name,
                          _getExerciseGifPath(exercise.name),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: GestureDetector(
                        onTap: () => _showInstructionsDialog(exercise),
                        child: Icon(
                          Icons.info_outline,
                          color: TColor.primary,
                          size: 28,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3.0,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // "For Best Detection" section
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TColor.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'For Best Detection:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: TColor.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        detectionInstructions,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Improved exercise parameters section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Exercise Parameters",
                        style: TextStyle(
                          color: TColor.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Sets input with icon
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: TColor.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.format_list_numbered,
                              color: TColor.primary,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: setsController,
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Number of Sets*',
                                labelStyle: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                hintText: 'e.g., 3',
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: TColor.primary),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: TColor.primary.withOpacity(0.5),
                                  ),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                              ),
                              cursorColor: TColor.primary,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  sets = int.tryParse(value) ?? 0;
                                  exercise.sets = sets;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Reps input with icon (keeping fitness_center icon as it's appropriate)
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: TColor.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: TColor.primary,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: repsController,
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Reps per Set*',
                                labelStyle: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                hintText: 'e.g., 10',
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: TColor.primary),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: TColor.primary.withOpacity(0.5),
                                  ),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                              ),
                              cursorColor: TColor.primary,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  reps = int.tryParse(value) ?? 0;
                                  exercise.reps = reps;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Rest time input with icon (keeping timer icon as it's appropriate)
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: TColor.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.timer,
                              color: TColor.primary,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: restTimeController,
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Rest Time (seconds)*',
                                labelStyle: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                hintText: 'e.g., 30',
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: TColor.primary),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: TColor.primary.withOpacity(0.5),
                                  ),
                                ),
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                              ),
                              cursorColor: TColor.primary,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  restTime = int.tryParse(value) ?? 0;
                                  exercise.restTime = restTime;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8),
                Text(
                  '* Required fields',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (sets > 0 && reps > 0 && restTime > 0)
                            ? () async {
                                Navigator.of(context).pop();
                                try {
                                  String exerciseType = '';
                                  if (exercise.name == 'Push Ups') {
                                    exerciseType = 'Push-up';
                                  } else if (exercise.name == 'Jumping Jacks') {
                                    exerciseType = 'Jumping Jack';
                                  } else if (exercise.name == 'Squat') {
                                    exerciseType = 'Squat';
                                  } else if (exercise.name == 'Pull Ups') {
                                    exerciseType = 'Pull Up';
                                  } else if (exercise.name == 'Sit Ups') {
                                    exerciseType = 'Sit Up';
                                  }

                                  print("Starting exercise: $exerciseType");

                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => MultiBlocProvider(
                                        providers: [
                                          BlocProvider<PushUpCounter>(
                                            create: (context) =>
                                                PushUpCounter(),
                                          ),
                                          BlocProvider<JumpingJackCounter>(
                                            create: (context) =>
                                                JumpingJackCounter(),
                                          ),
                                          BlocProvider<SquatCounter>(
                                            create: (context) => SquatCounter(),
                                          ),
                                          BlocProvider<PullUpCounter>(
                                            create: (context) =>
                                                PullUpCounter(),
                                          ),
                                          BlocProvider<SitUpCounter>(
                                            create: (context) => SitUpCounter(),
                                          ),
                                        ],
                                        child: PoseDetectorView(
                                          exerciseType: exerciseType,
                                          targetSets: exercise.sets,
                                          targetReps: exercise.reps,
                                          restTime: exercise.restTime,
                                        ),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: Text('Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (sets > 0 && reps > 0 && restTime > 0)
                                  ? TColor.primary
                                  : Colors.grey,
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        centerTitle: true,
        elevation: 10.0,
        shadowColor: Colors.black.withOpacity(0.5),
        title: Text(
          "GRIT",
          style: TextStyle(
              color: TColor.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showHistory ? Icons.grid_view : Icons.history,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showHistory = !_showHistory;

                // Reload history data when switching to history view
                if (_showHistory) {
                  _loadExerciseHistory();
                }
              });
            },
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: TColor.primary))
          : _showHistory
              ? _buildHistoryView()
              : _buildExerciseGrid(),
    );
  }

  Widget _buildExerciseGrid() {
    return Container(
      color: Colors.white,
      child: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showExerciseDialog(exercises[index]),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        TColor.primary,
                        TColor.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: TColor.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          exercises[index].icon ??
                              Icons.fitness_center, // Provide default icon
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        exercises[index].name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Start',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryView() {
    if (exerciseHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.withOpacity(0.5)),
            SizedBox(height: 20),
            Text(
              "No Exercise History",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: TColor.primary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Complete exercises to see them here",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey.shade50,
      child: RefreshIndicator(
        onRefresh: _loadExerciseHistory,
        color: TColor.primary,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: exerciseHistory.length,
          itemBuilder: (context, index) {
            final exercise = exerciseHistory[index];
            print("Rendering history item: ${exercise['exerciseName']}");

            // Format date
            String formattedDate = "Just now";
            if (exercise.containsKey('timestamp') &&
                exercise['timestamp'] != null) {
              final timestamp = exercise['timestamp'] as Timestamp;
              final dateTime = timestamp.toDate();
              final now = DateTime.now();
              final difference = now.difference(dateTime);

              if (difference.inDays > 0) {
                formattedDate =
                    '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
              } else if (difference.inHours > 0) {
                formattedDate =
                    '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
              } else if (difference.inMinutes > 0) {
                formattedDate =
                    '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
              }
            }

            // Calculate progress
            final int completion = exercise['completion'] as int? ?? 0;
            final Color progressColor = completion >= 100
                ? Colors.green
                : completion >= 75
                    ? Colors.blue
                    : completion >= 50
                        ? Colors.orange
                        : Colors.red;

            // Get appropriate icon and display name based on stored exercise name
            IconData exerciseIcon = Icons.fitness_center;
            String displayName = exercise['exerciseName'] ?? "Unknown Exercise";

            switch (exercise['exerciseName']) {
              case 'Push-up':
                exerciseIcon = Icons.fitness_center;
                displayName = 'Push Ups';
                break;
              case 'Pull Up':
              case 'Pull Ups':
                exerciseIcon = Icons.fitness_center;
                displayName = 'Pull Ups';
                break;
              case 'Jumping Jack':
              case 'Jumping Jacks':
                exerciseIcon = Icons.directions_run;
                displayName = 'Jumping Jacks';
                break;
              case 'Squat':
                exerciseIcon = Icons.accessibility_new;
                break;
              case 'Sit Up':
              case 'Sit Ups':
                exerciseIcon = Icons.accessibility_new;
                displayName = 'Sit Ups';
                break;
            }

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              margin: EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.grey.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Header section
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TColor.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              exerciseIcon,
                              color: TColor.primary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: progressColor.withOpacity(0.1),
                              border: Border.all(
                                color: progressColor,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                "$completion%",
                                style: TextStyle(
                                  color: progressColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.withOpacity(0.2),
                    ),

                    // Details section
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn(
                            "Sets",
                            "${exercise['completedSets'] ?? 0}/${exercise['targetSets'] ?? 0}",
                            Icons.repeat,
                          ),
                          _buildDivider(),
                          _buildStatColumn(
                            "Reps",
                            "${exercise['completedReps'] ?? 0}",
                            Icons.fitness_center,
                          ),
                          _buildDivider(),
                          _buildStatColumn(
                            "Rest",
                            "${exercise['restTime'] ?? 0}s",
                            Icons.timer,
                          ),
                        ],
                      ),
                    ),

                    // Progress bar
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Completion",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: completion / 100,
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(progressColor),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
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
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: TColor.primary.withOpacity(0.7),
          size: 20,
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
