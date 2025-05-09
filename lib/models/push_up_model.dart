import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;

enum PushUpState { neutral, init, complete }

class PushUpCounter extends Cubit<PushUpState> {
  PushUpCounter() : super(PushUpState.neutral);
  int counter = 0;

  void setPushUpState(PushUpState current) {
    developer.log('Setting push-up state: $current');
    emit(current);
  }

  void increment() {
    counter++;
    developer.log('Push-up counted! New total: $counter');
    // Force a state change to trigger UI update
    emit(PushUpState.neutral);
  }

  void reset() {
    counter = 0;
    emit(PushUpState.neutral);
  }
}
