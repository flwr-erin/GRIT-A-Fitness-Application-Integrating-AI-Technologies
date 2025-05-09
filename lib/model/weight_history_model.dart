class WeightHistoryModel {
  final String uid;
  final double weight;
  final double height;
  final DateTime dateTime;

  WeightHistoryModel({
    required this.uid,
    required this.weight,
    required this.height,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'weight': weight,
        'height': height,
        'dateTime': dateTime.toIso8601String(),
      };

  static WeightHistoryModel fromJson(Map<String, dynamic> json) =>
      WeightHistoryModel(
        uid: json['uid'],
        weight: json['weight'].toDouble(),
        height: json['height'].toDouble(),
        dateTime: DateTime.parse(json['dateTime']),
      );
}
