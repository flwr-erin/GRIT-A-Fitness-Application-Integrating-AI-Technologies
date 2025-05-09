import 'package:cloud_firestore/cloud_firestore.dart';

class PresetWorkoutService {
  final FirebaseFirestore _firestore;

  PresetWorkoutService(this._firestore);

  /// Get all preset workout plans
  Future<List<Map<String, dynamic>>> getPresetWorkoutPlans() async {
    try {
      final snapshot = await _firestore
          .collection('preset_workout_plans')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      print('Error loading preset workout plans: $e');
      return [];
    }
  }

  /// Get preset workout plans by level (beginner, intermediate, advanced)
  Future<List<Map<String, dynamic>>> getPresetWorkoutPlansByLevel(
      String level) async {
    try {
      final snapshot = await _firestore
          .collection('preset_workout_plans')
          .where('level', isEqualTo: level)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      print('Error loading preset workout plans by level: $e');
      return [];
    }
  }

  /// Get a single preset workout plan by ID
  Future<Map<String, dynamic>?> getPresetWorkoutPlanById(String id) async {
    try {
      final doc =
          await _firestore.collection('preset_workout_plans').doc(id).get();

      if (doc.exists && doc.data() != null) {
        return {...doc.data()!, 'id': doc.id};
      }
      return null;
    } catch (e) {
      print('Error loading preset workout plan: $e');
      return null;
    }
  }
}
