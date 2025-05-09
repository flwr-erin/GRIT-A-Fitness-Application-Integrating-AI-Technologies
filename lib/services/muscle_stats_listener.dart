import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MuscleStatsListener {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, Map<String, dynamic>> _previousStats = {};
  final String userId;
  final BuildContext context;

  MuscleStatsListener({required this.userId, required this.context});

  // Initialize with current stats
  Future<void> initialize(
      Map<String, Map<String, dynamic>> currentStats) async {
    _previousStats = Map.from(currentStats);
  }

  // Check for level-ups and show notifications
  Future<void> checkForLevelUps(
      Map<String, Map<String, dynamic>> newStats) async {
    if (_previousStats.isEmpty) {
      _previousStats = Map.from(newStats);
      return;
    }

    // Batch all level up notifications
    List<Widget> levelUpWidgets = [];

    // Check each muscle group for level-ups
    for (final muscleGroup in newStats.keys) {
      final newLevel = newStats[muscleGroup]?['level'] as int? ?? 1;
      final oldLevel = _previousStats[muscleGroup]?['level'] as int? ?? 1;

      // If there's a level up, prepare notification
      if (newLevel > oldLevel) {
        // Add to the batch instead of showing immediately
        levelUpWidgets.add(_buildLevelUpNotification(muscleGroup, newLevel));
      }
    }

    // Show all level up notifications at once if there are any
    if (levelUpWidgets.isNotEmpty) {
      _showLevelUpBatch(levelUpWidgets);
    }

    // Update previous stats
    _previousStats = Map.from(newStats);
  }

  // Build a level up notification widget
  Widget _buildLevelUpNotification(String muscleGroup, int newLevel) {
    // Get muscle icon
    IconData muscleIcon = _getMuscleIcon(muscleGroup);
    Color muscleColor = _getMuscleColor(muscleGroup);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: muscleColor.withOpacity(0.3),
            blurRadius: 5,
            spreadRadius: 1,
          )
        ],
        border: Border.all(color: muscleColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: muscleColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              muscleIcon,
              color: muscleColor,
              size: 24,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LEVEL UP!",
                  style: TextStyle(
                    color: muscleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${_capitalizeFirstLetter(muscleGroup)} reached Level $newLevel",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Celebration icon
          Icon(
            Icons.celebration,
            color: muscleColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  // Show all level up notifications in one dialog
  void _showLevelUpBatch(List<Widget> levelUpWidgets) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Congratulations!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: levelUpWidgets,
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text("Awesome!", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Original method for backward compatibility - now redirects to the new batch method
  void _showLevelUpNotification(String muscleGroup, int newLevel) {
    _showLevelUpBatch([_buildLevelUpNotification(muscleGroup, newLevel)]);
  }

  // Helper for capitalizing
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Get muscle icon for visualization
  IconData _getMuscleIcon(String muscleGroup) {
    switch (muscleGroup) {
      case 'chest':
        return Icons.accessibility_new;
      case 'back':
        return Icons.airline_seat_flat;
      case 'arms':
        return Icons.fitness_center;
      case 'abdominals':
        return Icons.straighten;
      case 'legs':
        return Icons.directions_walk;
      case 'shoulders':
        return Icons.architecture;
      default:
        return Icons.fitness_center;
    }
  }

  // Get muscle color for visualization
  Color _getMuscleColor(String muscleGroup) {
    switch (muscleGroup) {
      case 'chest':
        return Colors.red[700]!;
      case 'back':
        return Colors.blue[700]!;
      case 'arms':
        return Colors.green[700]!;
      case 'abdominals':
        return Colors.orange[700]!;
      case 'legs':
        return Colors.purple[700]!;
      case 'shoulders':
        return Colors.teal[700]!;
      default:
        return Colors.deepPurple;
    }
  }
}
