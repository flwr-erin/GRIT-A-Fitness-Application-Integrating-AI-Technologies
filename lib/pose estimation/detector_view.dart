import 'package:camera/camera.dart';
import 'package:fitness_app/painters/pose_painter.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import 'camera_view.dart';
import 'gallery_view.dart';

enum DetectorViewMode { liveFeed, gallery }

class DetectorView extends StatefulWidget {
  const DetectorView({
    super.key,
    this.posePainter,
    required this.title,
    required this.onImage,
    this.customPaint,
    this.text,
    this.initialDetectionMode = DetectorViewMode.liveFeed,
    this.initialCameraLensDirection = CameraLensDirection.back,
    this.onCameraFeedReady,
    this.onDetectorViewModeChanged,
    this.onCameraLensDirectionChanged,
    required this.exerciseType,
    required this.targetSets,
    required this.targetReps,
    required this.restTime,
  });

  final PosePainter? posePainter;
  final String title;
  final CustomPaint? customPaint;
  final String? text;
  final DetectorViewMode initialDetectionMode;
  final Function(InputImage inputImage) onImage;
  final Function()? onCameraFeedReady;
  final Function(DetectorViewMode mode)? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;
  final String exerciseType;
  final int targetSets;
  final int targetReps;
  final int restTime;

  @override
  State<DetectorView> createState() => _DetectorViewState();
}

class _DetectorViewState extends State<DetectorView> {
  late DetectorViewMode _mode;

  @override
  void initState() {
    _mode = widget.initialDetectionMode;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _mode == DetectorViewMode.liveFeed
        ? CameraView(
            posePainter: widget.posePainter,
            customPaint: widget.customPaint,
            onImage: widget.onImage,
            onCameraFeedReady: widget.onCameraFeedReady,
            onDetectorViewModeChanged: _onDetectorViewModeChanged,
            initialCameraLensDirection: widget.initialCameraLensDirection,
            onCameraLensDirectionChanged: widget.onCameraLensDirectionChanged,
            exerciseType: widget.exerciseType,
            targetSets: widget.targetSets,
            targetReps: widget.targetReps,
            restTime: widget.restTime,
          )
        : GalleryView(
            title: widget.title,
            text: widget.text,
            onImage: widget.onImage,
            onDetectorViewModeChanged: _onDetectorViewModeChanged);
  }

  void _onDetectorViewModeChanged() {
    if (_mode == DetectorViewMode.liveFeed) {
      _mode = DetectorViewMode.gallery;
    } else {
      _mode = DetectorViewMode.liveFeed;
    }
    if (widget.onDetectorViewModeChanged != null) {
      widget.onDetectorViewModeChanged!(_mode);
    }
    setState(() {});
  }
}
