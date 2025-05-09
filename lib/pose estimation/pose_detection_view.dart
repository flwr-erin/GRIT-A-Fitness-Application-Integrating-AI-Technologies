import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../painters/pose_painter.dart';
import '../models/jumping_jack_model.dart';
import '../models/push_up_model.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/squat_model.dart';
import 'package:fitness_app/models/pull_up_model.dart';
import 'package:fitness_app/models/sit_up_model.dart';
import 'detector_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PoseDetectorView extends StatefulWidget {
  final String exerciseType;
  final int targetSets;
  final int targetReps;
  final int restTime;

  const PoseDetectorView({
    super.key,
    required this.exerciseType,
    required this.targetSets,
    required this.targetReps,
    required this.restTime,
  });

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  PosePainter? _posePainter;
  var _cameraLensDirection = CameraLensDirection.back;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? username;
  String? userId;

  // Exercise completion tracking
  int completedSets = 0;
  int completedReps = 0;
  bool exerciseCompleted = false;

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
          });
        } else {
          print('User not found for username: $storedUsername');
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _saveExerciseToDatabase() async {
    if (userId == null) {
      print('Cannot save exercise: userId is null');
      return;
    }

    try {
      // Create the exercise record
      await _firestore.collection('pose_exercise_history').add({
        'userId': userId,
        'username': username,
        'exerciseName': widget.exerciseType,
        'targetSets': widget.targetSets,
        'targetReps': widget.targetReps,
        'restTime': widget.restTime,
        'completedSets': completedSets,
        'completedReps': completedReps,
        'completion': (completedSets / widget.targetSets * 100).round(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Exercise saved successfully: ${widget.exerciseType}');
    } catch (e) {
      print('Error saving exercise: $e');
    }
  }

  @override
  void dispose() {
    _canProcess = false;
    _poseDetector.close();

    // Save exercise data when view is disposed
    if (completedReps > 0) {
      _saveExerciseToDatabase();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to exercise counter blocs to track completion
    if (widget.exerciseType.contains('Push-up')) {
      return BlocListener<PushUpCounter, PushUpState>(
        listener: (context, state) {
          final counter = context.read<PushUpCounter>().counter;
          _updateCompletionState(counter);
        },
        child: _buildDetectorView(),
      );
    } else if (widget.exerciseType.contains('Jumping Jack')) {
      return BlocListener<JumpingJackCounter, JumpingJackState>(
        listener: (context, state) {
          final counter = context.read<JumpingJackCounter>().counter;
          _updateCompletionState(counter);
        },
        child: _buildDetectorView(),
      );
    } else if (widget.exerciseType.contains('Squat')) {
      return BlocListener<SquatCounter, SquatState>(
        listener: (context, state) {
          final counter = context.read<SquatCounter>().counter;
          _updateCompletionState(counter);
        },
        child: _buildDetectorView(),
      );
    } else if (widget.exerciseType.contains('Pull Up')) {
      return BlocListener<PullUpCounter, PullUpState>(
        listener: (context, state) {
          final counter = context.read<PullUpCounter>().counter;
          _updateCompletionState(counter);
        },
        child: _buildDetectorView(),
      );
    } else if (widget.exerciseType.contains('Sit Up')) {
      return BlocListener<SitUpCounter, SitUpState>(
        listener: (context, state) {
          final counter = context.read<SitUpCounter>().counter;
          _updateCompletionState(counter);
        },
        child: _buildDetectorView(),
      );
    } else {
      return _buildDetectorView();
    }
  }

  void _updateCompletionState(int counter) {
    if (counter > 0 &&
        counter % widget.targetReps == 0 &&
        counter > completedReps) {
      // When target reps are completed, increment sets
      setState(() {
        completedReps = counter;
        completedSets++;

        if (completedSets >= widget.targetSets) {
          exerciseCompleted = true;
        }
      });
    } else {
      setState(() {
        completedReps = counter;
      });
    }
  }

  Widget _buildDetectorView() {
    return DetectorView(
      title: widget.exerciseType,
      customPaint: _customPaint,
      text: _text,
      onImage: _processImage,
      posePainter: _posePainter,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
      exerciseType: widget.exerciseType,
      targetSets: widget.targetSets,
      targetReps: widget.targetReps,
      restTime: widget.restTime,
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final poses = await _poseDetector.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      _posePainter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: _posePainter);
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
