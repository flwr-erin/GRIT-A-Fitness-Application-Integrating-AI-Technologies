import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:fitness_app/models/jumping_jack_model.dart';
import 'package:fitness_app/models/pull_up_model.dart';
import 'package:fitness_app/models/push_up_model.dart';
import 'package:fitness_app/models/sit_up_model.dart';
import 'package:fitness_app/models/squat_model.dart';
import 'package:fitness_app/painters/pose_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:fitness_app/utils.dart'
    as utils; // Add this line to import the utils package
import 'dart:developer' as developer;

class CameraView extends StatefulWidget {
  final String exerciseType;
  final int targetSets;
  final int targetReps;
  final int restTime;

  const CameraView(
      {super.key,
      required this.customPaint,
      required this.onImage,
      required this.posePainter,
      this.onCameraFeedReady,
      this.onDetectorViewModeChanged,
      this.onCameraLensDirectionChanged,
      this.initialCameraLensDirection = CameraLensDirection.back,
      required this.exerciseType,
      required this.targetSets,
      required this.targetReps,
      required this.restTime});

  final PosePainter? posePainter;
  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final VoidCallback? onCameraFeedReady;
  final VoidCallback? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = -1;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  bool _changingCameraLens = false;

  PoseLandmark? p1;
  PoseLandmark? p2;
  PoseLandmark? p3;

  int currentSet = 1;
  bool isResting = false;
  int restTimeRemaining = 0;
  Timer? restTimer;

  bool _setCompleted = false;
  bool _exerciseComplete = false;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void didUpdateWidget(covariant CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customPaint != oldWidget.customPaint) {
      if (widget.posePainter == null || widget.posePainter!.poses.isEmpty)
        return;

      for (final pose in widget.posePainter!.poses) {
        try {
          developer.log('Processing exercise: ${widget.exerciseType}');

          if (widget.exerciseType.contains('Push-up')) {
            _processPushUp(pose);
          } else if (widget.exerciseType.contains('Jumping Jack')) {
            _processJumpingJack(pose);
          } else if (widget.exerciseType.contains('Squat')) {
            _processSquat(pose);
          } else if (widget.exerciseType.contains('Pull Up')) {
            _processPullUp(pose);
          } else if (widget.exerciseType.contains('Sit Up')) {
            _processSitUp(pose);
          }
        } catch (e) {
          developer.log('Error in pose detection: $e');
        }
      }
    }
  }

  void _processPushUp(Pose pose) {
    if (isResting || _exerciseComplete) return; // Add _exerciseComplete check
    try {
      final bloc = BlocProvider.of<PushUpCounter>(context);

      // Get right arm landmarks
      final shoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final elbow = pose.landmarks[PoseLandmarkType.rightElbow];
      final wrist = pose.landmarks[PoseLandmarkType.rightWrist];

      if (shoulder != null && elbow != null && wrist != null) {
        final angle = utils.angle(shoulder, elbow, wrist);
        developer.log('Push-up raw angle: $angle');

        final pushUpState = utils.isPushUp(angle, bloc.state);
        if (pushUpState != null) {
          bloc.setPushUpState(pushUpState);
          if (pushUpState == PushUpState.complete) {
            bloc.increment();
            developer.log('Push-up counted! Total: ${bloc.counter}');
          }
        }
      }
    } catch (e) {
      developer.log('Error in push-up processing: $e');
    }
  }

  void _processJumpingJack(Pose pose) {
    if (isResting || _exerciseComplete) return; // Add _exerciseComplete check
    try {
      final bloc = BlocProvider.of<JumpingJackCounter>(context);
      final landmarks = pose.landmarks.values.toList();

      final jackState = utils.detectJumpingJack(landmarks, bloc.state);

      if (jackState != null) {
        developer.log('Jumping jack state changed to: $jackState');
        bloc.setJumpingJackState(jackState);
        if (jackState == JumpingJackState.arms_down) {
          bloc.increment();
          developer.log('Jumping jack counted! Total: ${bloc.counter}');
        }
      }
    } catch (e) {
      developer.log('Error in jumping jack processing: $e');
    }
  }

  void _processSquat(Pose pose) {
    if (isResting || _exerciseComplete) return; // Add _exerciseComplete check
    try {
      final bloc = BlocProvider.of<SquatCounter>(context);
      final landmarks = pose.landmarks.values.toList();

      final squatState = utils.isSquat(landmarks, bloc.state);
      if (squatState != null) {
        developer.log('Squat state changed to: $squatState');
        bloc.setSquatState(squatState);
        if (squatState == SquatState.complete) {
          bloc.increment();
          developer.log('Squat counted! Total: ${bloc.counter}');
        }
      }
    } catch (e) {
      developer.log('Error in squat processing: $e');
    }
  }

  void _processPullUp(Pose pose) {
    if (isResting || _exerciseComplete) return;
    try {
      final bloc = BlocProvider.of<PullUpCounter>(context);
      final landmarks = pose.landmarks.values.toList();

      final pullUpState = utils.isPullUp(landmarks, bloc.state);
      if (pullUpState != null) {
        bloc.setPullUpState(pullUpState);
        if (pullUpState == PullUpState.complete) {
          bloc.increment();
          developer.log('Pull-up counted! Total: ${bloc.counter}');
        }
      }
    } catch (e) {
      developer.log('Error in pull-up processing: $e');
    }
  }

  void _processSitUp(Pose pose) {
    if (isResting || _exerciseComplete) return;
    try {
      final bloc = BlocProvider.of<SitUpCounter>(context);
      final landmarks = pose.landmarks.values.toList();

      final sitUpState = utils.isSitUp(landmarks, bloc.state);
      if (sitUpState != null) {
        bloc.setSitUpState(sitUpState);
        if (sitUpState == SitUpState.complete) {
          bloc.increment();
          developer.log('Sit-up counted! Total: ${bloc.counter}');
        }
      }
    } catch (e) {
      developer.log('Error in sit-up processing: $e');
    }
  }

  void startRestTimer() {
    if (isResting || currentSet >= widget.targetSets)
      return; // Don't start timer if it's the last set

    // Cancel any existing timer
    restTimer?.cancel();

    setState(() {
      isResting = true;
      restTimeRemaining = widget.restTime;
      _setCompleted = false;
    });

    restTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (restTimeRemaining > 0) {
          restTimeRemaining--;
        } else {
          isResting = false;
          timer.cancel();

          if (currentSet < widget.targetSets) {
            currentSet++;
            _resetCounter();
          } else {
            _exerciseComplete = true;
            // Show completion dialog in post-frame callback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCompletionDialog();
            });
          }
        }
      });
    });
  }

  void _resetCounter() {
    if (widget.exerciseType.contains('Push-up')) {
      context.read<PushUpCounter>().reset();
    } else if (widget.exerciseType.contains('Jumping Jack')) {
      context.read<JumpingJackCounter>().reset();
    } else if (widget.exerciseType.contains('Squat')) {
      context.read<SquatCounter>().reset();
    } else if (widget.exerciseType.contains('Pull Up')) {
      context.read<PullUpCounter>().reset();
    } else if (widget.exerciseType.contains('Sit Up')) {
      context.read<SitUpCounter>().reset();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white24,
            width: 2,
          ),
        ),
        title: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 50,
            ),
            SizedBox(height: 10),
            Text(
              'Workout Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great job! You completed:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '${widget.targetSets} Sets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.targetSets * widget.targetReps} Total Reps',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to previous screen
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white24,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'FINISH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
        actionsPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  void checkSetCompletion(int currentReps) {
    if (!isResting &&
        !_setCompleted &&
        currentReps >= widget.targetReps &&
        !_exerciseComplete) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setCompleted = true;

        // Check if this is the final set
        if (currentSet >= widget.targetSets) {
          setState(() {
            _exerciseComplete = true; // Set in setState to ensure UI updates
          });
          _showCompletionDialog();
        } else {
          startRestTimer();
        }
      });
    }
  }

  @override
  void dispose() {
    restTimer?.cancel();
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _liveFeedBody());
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return Container();
    if (_controller == null) return Container();
    if (_controller?.value.isInitialized == false) return Container();
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: _changingCameraLens
                ? Center(
                    child: const Text('Changing camera lens'),
                  )
                : CameraPreview(
                    _controller!,
                    child: widget.customPaint,
                  ),
          ),
          _counterWidget(),
          if (isResting) _restTimerOverlay(),
          _backButton(),
          _switchLiveCameraToggle(),
          _detectionViewModeToggle(),
          _zoomControl(),
          _exposureControl(),
        ],
      ),
    );
  }

  Widget _restTimerOverlay() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(30), // Increased padding
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85), // Slightly more opaque
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'REST TIME',
              style: TextStyle(
                color: Colors.white,
                fontSize: 35, // Increased size
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '$restTimeRemaining',
              style: TextStyle(
                color: Colors.white,
                fontSize: 80, // Increased size
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'seconds',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25, // Increased size
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Next: Set ${currentSet + 1}/${widget.targetSets}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25, // Increased size
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterWidget() {
    return Positioned(
      left: 0,
      top: 50,
      right: 0,
      child: Column(
        children: [
          Text(
            widget.exerciseType,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28, // Reduced from 32
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 5,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
          BlocBuilder<PushUpCounter, PushUpState>(
            builder: (context, pushUpState) {
              return BlocBuilder<JumpingJackCounter, JumpingJackState>(
                builder: (context, jumpingJackState) {
                  return BlocBuilder<SquatCounter, SquatState>(
                    builder: (context, squatState) {
                      return BlocBuilder<PullUpCounter, PullUpState>(
                        builder: (context, pullUpState) {
                          return BlocBuilder<SitUpCounter, SitUpState>(
                            builder: (context, sitUpState) {
                              int count = 0;
                              if (widget.exerciseType.contains('Push-up')) {
                                count = context.watch<PushUpCounter>().counter;
                              } else if (widget.exerciseType
                                  .contains('Jumping Jack')) {
                                count =
                                    context.watch<JumpingJackCounter>().counter;
                              } else if (widget.exerciseType
                                  .contains('Squat')) {
                                count = context.watch<SquatCounter>().counter;
                              } else if (widget.exerciseType
                                  .contains('Pull Up')) {
                                count = context.watch<PullUpCounter>().counter;
                              } else if (widget.exerciseType
                                  .contains('Sit Up')) {
                                count = context.watch<SitUpCounter>().counter;
                              }

                              // Move checkSetCompletion to post-frame callback
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && !isResting) {
                                  checkSetCompletion(count);
                                }
                              });

                              return Column(
                                children: [
                                  // Set Counter
                                  Container(
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 20),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white24,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      _exerciseComplete
                                          ? "WORKOUT COMPLETE!"
                                          : "SET ${currentSet}/${widget.targetSets}",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22, // Reduced from 26
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  // Reps Counter
                                  Container(
                                    width: 120,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isResting
                                          ? Colors.grey.withOpacity(0.5)
                                          : Colors.black87,
                                      border: Border.all(
                                          color: Colors.white24, width: 1.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          "$count/${widget.targetReps}",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 36, // Reduced from 45
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isResting)
                                          Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              "PAUSED",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _backButton() => Positioned(
        top: 40,
        left: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: () {
              try {
                if (widget.exerciseType.contains('Push-up')) {
                  context.read<PushUpCounter>().reset();
                } else if (widget.exerciseType.contains('Jumping Jack')) {
                  context.read<JumpingJackCounter>().reset();
                } else if (widget.exerciseType.contains('Squat')) {
                  context.read<SquatCounter>().reset();
                }
              } finally {
                Navigator.of(context).pop();
              }
            },
            backgroundColor: Colors.black54,
            child: Icon(Icons.arrow_back_ios_outlined, size: 20),
          ),
        ),
      );

  Widget _detectionViewModeToggle() => Positioned(
        bottom: 8,
        left: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: widget.onDetectorViewModeChanged,
            backgroundColor: Colors.black54,
            child: Icon(
              Icons.photo_library_outlined,
              size: 25,
            ),
          ),
        ),
      );

  Widget _switchLiveCameraToggle() => Positioned(
        bottom: 8,
        right: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: _switchLiveCamera,
            backgroundColor: Colors.black54,
            child: Icon(
              Platform.isIOS
                  ? Icons.flip_camera_ios_outlined
                  : Icons.flip_camera_android_outlined,
              size: 25,
            ),
          ),
        ),
      );

  Widget _zoomControl() => Positioned(
        bottom: 16,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 250,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Slider(
                    value: _currentZoomLevel,
                    min: _minAvailableZoom,
                    max: _maxAvailableZoom,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                    onChanged: (value) async {
                      setState(() {
                        _currentZoomLevel = value;
                      });
                      await _controller?.setZoomLevel(value);
                    },
                  ),
                ),
                Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        '${_currentZoomLevel.toStringAsFixed(1)}x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _exposureControl() => Positioned(
        top: 40,
        right: 8,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 250,
          ),
          child: Column(children: [
            Container(
              width: 55,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    '${_currentExposureOffset.toStringAsFixed(1)}x',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SizedBox(
                  height: 30,
                  child: Slider(
                    value: _currentExposureOffset,
                    min: _minAvailableExposureOffset,
                    max: _maxAvailableExposureOffset,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                    onChanged: (value) async {
                      setState(() {
                        _currentExposureOffset = value;
                      });
                      await _controller?.setExposureOffset(value);
                    },
                  ),
                ),
              ),
            )
          ]),
        ),
      );

  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        _currentZoomLevel = value;
        _minAvailableZoom = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        _maxAvailableZoom = value;
      });
      _currentExposureOffset = 0.0;
      _controller?.getMinExposureOffset().then((value) {
        _minAvailableExposureOffset = value;
      });
      _controller?.getMaxExposureOffset().then((value) {
        _maxAvailableExposureOffset = value;
      });
      _controller?.startImageStream(_processCameraImage).then((value) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
        if (widget.onCameraLensDirectionChanged != null) {
          widget.onCameraLensDirectionChanged!(camera.lensDirection);
        }
      });
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    widget.onImage(inputImage);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
}
