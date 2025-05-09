import 'dart:io';
import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:fitness_app/models/jumping_jack_model.dart';
import 'package:fitness_app/models/pull_up_model.dart';
import 'package:fitness_app/models/push_up_model.dart';
import 'package:fitness_app/models/sit_up_model.dart';
import 'package:fitness_app/models/squat_model.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<String> getAssetPath(String asset) async {
  final path = await getLocalPath(asset);
  await Directory(dirname(path)).create(recursive: true);
  final file = File(path);
  if (!await file.exists()) {
    final byteData = await rootBundle.load(asset);
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }
  return file.path;
}

Future<String> getLocalPath(String path) async {
  return '${(await getApplicationSupportDirectory()).path}/$path';
}

double angle(PoseLandmark firstLandmark, PoseLandmark midLandmark,
    PoseLandmark lastLandmark) {
  final radians = math.atan2(
          lastLandmark.y - midLandmark.y, lastLandmark.x - midLandmark.x) -
      math.atan2(
          firstLandmark.y - midLandmark.y, firstLandmark.x - midLandmark.x);

  double degrees = radians * 180.0 / math.pi;
  degrees = degrees.abs();
  if (degrees > 180.0) {
    degrees = 360.0 - degrees;
  }

  return degrees;
}

PushUpState? isPushUp(double angleElbow, PushUpState current) {
  // More forgiving thresholds
  final umbralElbow = 110.0; // Changed from 80.0
  final umbralElbowExt = 150.0; // Changed from 130.0

  developer.log('Push-up check - Angle: $angleElbow, State: $current');

  // Starting position (arms straight)
  if (current == PushUpState.neutral && angleElbow > umbralElbowExt) {
    developer.log('Push-up: Start position detected');
    return PushUpState.init;
  }
  // Bottom position (arms bent)
  else if (current == PushUpState.init && angleElbow < umbralElbow) {
    developer.log('Push-up: Bottom position detected');
    return PushUpState.complete;
  }
  // Reset if form breaks
  else if (current == PushUpState.complete) {
    developer.log('Push-up: Resetting to neutral');
    return PushUpState.neutral;
  }

  return null;
}

JumpingJackState? detectJumpingJack(
    List<PoseLandmark> landmarks, JumpingJackState current) {
  try {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder.index];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder.index];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist.index];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist.index];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle.index];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle.index];
    final leftHip = landmarks[PoseLandmarkType.leftHip.index];
    final rightHip = landmarks[PoseLandmarkType.rightHip.index];

    // Calculate leg spread
    double hipWidth = (rightHip.x - leftHip.x).abs();
    double ankleWidth = (rightAnkle.x - leftAnkle.x).abs();

    // More forgiving thresholds
    bool armsUp = leftWrist.y < leftShoulder.y - 50 &&
        rightWrist.y < rightShoulder.y - 50;
    bool legsSpread = ankleWidth > hipWidth * 1.2;

    developer.log(
        'JJ - Arms up: $armsUp, Legs spread: $legsSpread, State: $current');

    switch (current) {
      case JumpingJackState.neutral:
        if (armsUp && legsSpread) {
          return JumpingJackState.arms_up;
        }
        break;
      case JumpingJackState.arms_up:
        if (!armsUp && !legsSpread) {
          return JumpingJackState.arms_down;
        }
        break;
      case JumpingJackState.arms_down:
        return JumpingJackState.neutral;
    }
  } catch (e) {
    developer.log('Error in jumping jack detection: $e');
  }
  return null;
}

SquatState? isSquat(List<PoseLandmark> landmarks, SquatState current) {
  try {
    final leftHip = landmarks[PoseLandmarkType.leftHip.index];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee.index];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle.index];

    // Calculate angle between hip, knee, and ankle
    double kneeAngle = angle(leftHip, leftKnee, leftAnkle);

    // Adjusted thresholds for better detection
    final squatThreshold = 130.0; // Higher angle for squat position
    final standThreshold = 150.0; // Lower angle for standing position

    developer.log(
        'Squat detection - Knee angle: $kneeAngle, Current state: $current');

    switch (current) {
      case SquatState.neutral:
        if (kneeAngle > standThreshold) {
          developer.log('Starting squat - standing position detected');
          return SquatState.down;
        }
        break;
      case SquatState.down:
        if (kneeAngle < squatThreshold) {
          developer.log('Squat bottom position detected');
          return SquatState.complete;
        }
        break;
      case SquatState.complete:
        developer.log('Squat completed, resetting to neutral');
        return SquatState.neutral;
    }
  } catch (e) {
    developer.log('Error in squat detection: $e');
  }
  return null;
}

PullUpState? isPullUp(List<PoseLandmark> landmarks, PullUpState current) {
  try {
    final nose = landmarks[PoseLandmarkType.nose.index];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist.index];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist.index];

    // Calculate average wrist height
    double avgWristY = (leftWrist.y + rightWrist.y) / 2;

    // Debug logs for values
    developer.log('Raw values - NoseY: ${nose.y}, WristY: $avgWristY');

    // Check positions with proper comparison
    bool isNoseAboveWrists =
        nose.y < avgWristY; // Removed tolerance for debugging
    bool isNoseBelowWrists = nose.y > avgWristY + 100;

    developer.log('Pull-up metrics - NoseY: ${nose.y}, WristY: $avgWristY, '
        'IsNoseAbove: $isNoseAboveWrists, IsNoseBelowWrists: $isNoseBelowWrists, '
        'Difference: ${nose.y - avgWristY}');

    switch (current) {
      case PullUpState.neutral:
        // Start position - nose should be lower than wrists
        if (nose.y > avgWristY + 50) {
          developer.log('Pull-up: Starting position detected');
          return PullUpState.init;
        }
        break;
      case PullUpState.init:
        // Top position - nose should be higher than wrists
        if (nose.y < avgWristY) {
          developer.log('Pull-up: Top position detected');
          return PullUpState.complete;
        }
        break;
      case PullUpState.complete:
        // Reset when nose goes back down
        if (nose.y > avgWristY + 50) {
          developer.log('Pull-up: Reset position detected');
          return PullUpState.neutral;
        }
        break;
    }
  } catch (e) {
    developer.log('Error in pull-up detection: $e');
  }
  return null;
}

SitUpState? isSitUp(List<PoseLandmark> landmarks, SitUpState current) {
  try {
    final nose = landmarks[PoseLandmarkType.nose.index];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder.index];
    final leftHip = landmarks[PoseLandmarkType.leftHip.index];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee.index];

    // Calculate torso angle
    double torsoAngle = angle(leftKnee, leftHip, leftShoulder);

    // Super forgiving thresholds
    bool isLyingDown = torsoAngle > 130; // Less strict angle for lying
    bool isSittingUp = torsoAngle < 100; // Much more forgiving upright position

    // Add vertical movement check
    bool isMovingUp = nose.y < leftHip.y;

    developer.log('Sit-up metrics - TorsoAngle: $torsoAngle, '
        'IsLying: $isLyingDown, IsSitting: $isSittingUp');

    switch (current) {
      case SitUpState.neutral:
        if (isLyingDown) {
          developer.log('Sit-up: Lying position detected');
          return SitUpState.init;
        }
        break;
      case SitUpState.init:
        if (isSittingUp && isMovingUp) {
          developer.log('Sit-up: Sitting position detected');
          return SitUpState.complete;
        }
        break;
      case SitUpState.complete:
        return SitUpState.neutral;
    }
  } catch (e) {
    developer.log('Error in sit-up detection: $e');
  }
  return null;
}
