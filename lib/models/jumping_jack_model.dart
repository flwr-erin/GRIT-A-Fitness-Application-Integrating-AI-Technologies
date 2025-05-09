import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;

enum JumpingJackState { neutral, arms_up, arms_down }

class JumpingJackCounter extends Cubit<JumpingJackState> {
  JumpingJackCounter() : super(JumpingJackState.neutral);
  int counter = 0;

  void setJumpingJackState(JumpingJackState current) {
    developer.log('Setting jumping jack state: $current');
    emit(current);
  }

  void increment() {
    counter++;
    developer.log('Jumping jack counted! New total: $counter');
    // Force a state change to trigger UI update
    emit(JumpingJackState.neutral);
  }

  void reset() {
    counter = 0;
    emit(JumpingJackState.neutral);
  }
}
