import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;

enum PullUpState {
  neutral,
  init,
  complete,
}

class PullUpCounter extends Cubit<PullUpState> {
  PullUpCounter() : super(PullUpState.neutral);
  int counter = 0;

  void increment() {
    counter++;
    developer.log('Pull-up counted! New total: $counter');
    emit(PullUpState.neutral);
  }

  void setPullUpState(PullUpState newState) {
    developer.log('Setting pull-up state: $newState');
    emit(newState);
  }

  void reset() {
    counter = 0;
    emit(PullUpState.neutral);
  }
}
