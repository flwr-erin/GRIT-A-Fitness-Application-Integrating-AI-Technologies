import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;

enum SquatState { neutral, down, complete }

class SquatCounter extends Cubit<SquatState> {
  SquatCounter() : super(SquatState.neutral);
  int counter = 0;

  void setSquatState(SquatState current) {
    developer.log('Setting squat state: $current');
    emit(current);
  }

  void increment() {
    counter++;
    developer.log('Squat counted! New total: $counter');
    emit(SquatState.neutral);
  }

  void reset() {
    counter = 0;
    emit(SquatState.neutral);
  }
}
