import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;

enum SitUpState {
  neutral,
  init,
  complete,
}

class SitUpCounter extends Cubit<SitUpState> {
  SitUpCounter() : super(SitUpState.neutral);
  int counter = 0;

  void increment() {
    counter++;
    developer.log('Sit-up counted! New total: $counter');
    emit(SitUpState.neutral);
  }

  void setSitUpState(SitUpState newState) {
    developer.log('Setting sit-up state: $newState');
    emit(newState);
  }

  void reset() {
    counter = 0;
    emit(SitUpState.neutral);
  }
}
