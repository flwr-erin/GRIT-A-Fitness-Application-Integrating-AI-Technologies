class WorkoutExerciseModel {
  final String name;
  final int sets;
  final int reps;
  final int restTime;
  final Map<String, dynamic> exerciseData;

  WorkoutExerciseModel({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restTime,
    required this.exerciseData,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'restTime': restTime,
      'exerciseData': exerciseData,
    };
  }

  factory WorkoutExerciseModel.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseModel(
      name: json['name'],
      sets: json['sets'],
      reps: json['reps'],
      restTime: json['restTime'],
      exerciseData: json['exerciseData'],
    );
  }
}
