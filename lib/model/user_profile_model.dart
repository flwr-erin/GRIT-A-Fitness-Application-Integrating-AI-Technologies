class UserProfileModel {
  final String uid;
  final DateTime birthDate;
  final String weight;
  final String height;
  final bool isMale;
  final int fitnessLevel; // 0: Beginner, 1: Intermediate, 2: Advanced

  UserProfileModel({
    required this.uid,
    required this.birthDate,
    required this.weight,
    required this.height,
    required this.isMale,
    required this.fitnessLevel,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'birthDate': DateTime(
          birthDate.year,
          birthDate.month,
          birthDate.day,
        ).toIso8601String(), // Store only date, no time
        'weight': weight,
        'height': height,
        'isMale': isMale,
        'fitnessLevel': fitnessLevel,
      };

  static UserProfileModel fromJson(Map<String, dynamic> json) {
    final dateStr = json['birthDate'];
    final parsedDate = DateTime.parse(dateStr);

    return UserProfileModel(
      uid: json['uid'],
      birthDate: DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      ), // Convert to date-only
      weight: json['weight'],
      height: json['height'],
      isMale: json['isMale'],
      fitnessLevel: json['fitnessLevel'],
    );
  }
}
