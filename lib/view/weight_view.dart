// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import '../../common/color_extension.dart';
import 'home/home_view.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/weight_history_model.dart';

class WeightView extends StatefulWidget {
  final String username; // Add username parameter
  final Function(double)? onWeightUpdate; // Add this line
  const WeightView(
      {Key? key,
      required this.username,
      this.onWeightUpdate,
      required double initialHeight})
      : super(key: key);

  @override
  State<WeightView> createState() => _WeightViewState();
}

class _WeightViewState extends State<WeightView> {
  bool _isLoading = true; // Add this line
  double userHeight = 0.0; // Changed from 170.0
  double userWeight = 0.0; // Changed from 70.0
  Map<DateTime, double> weightHistory = {};
  TextEditingController heightController = TextEditingController();
  TextEditingController weightController = TextEditingController();
  String? currentUserId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add these state variables
  double _currentHeight = 0.0;
  double _currentWeight = 0.0;

  double calculateBMI() {
    return userWeight / ((userHeight / 100) * (userHeight / 100));
  }

  String getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  @override
  void initState() {
    super.initState();
    // Initialize controllers with default values
    heightController = TextEditingController();
    weightController = TextEditingController();
    _loadUserProfile(); // Load user data from Firestore
  }

  Future<void> _loadUserProfile() async {
    try {
      print('Loading profile for username: ${widget.username}');

      // Get user profile directly using username as document ID
      final userProfileDoc = await _firestore
          .collection('user_profiles')
          .doc(widget.username) // Use username directly as document ID
          .get();

      if (!userProfileDoc.exists) {
        print('No profile found for username: ${widget.username}');
        setState(() => _isLoading = false);
        return;
      }

      final data = userProfileDoc.data()!;
      print('Raw profile data: $data');

      try {
        // Handle both string and numeric values
        var heightValue = data['height'];
        var weightValue = data['weight'];

        double height = 0.0;
        double weight = 0.0;

        // Parse height
        if (heightValue != null) {
          if (heightValue is String) {
            height = double.tryParse(
                    heightValue.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0.0;
          } else if (heightValue is num) {
            height = heightValue.toDouble();
          }
        }

        // Parse weight
        if (weightValue != null) {
          if (weightValue is String) {
            weight = double.tryParse(
                    weightValue.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0.0;
          } else if (weightValue is num) {
            weight = weightValue.toDouble();
          }
        }

        print('Parsed height: $height, weight: $weight');

        if (height > 0 && weight > 0) {
          setState(() {
            userHeight = height;
            userWeight = weight;
            heightController.text = height.toString();
            weightController.text = weight.toString();
          });
        }
      } catch (e) {
        print('Error parsing measurements: $e');
      }

      await _loadWeightHistory();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error in _loadUserProfile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> updateMeasurements() async {
    // Initialize current values when dialog opens
    _currentHeight =
        double.tryParse(heightController.text)?.roundToDouble() ?? userHeight;
    _currentWeight =
        double.tryParse(weightController.text)?.roundToDouble() ?? userWeight;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        // Wrap with StatefulBuilder
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: TColor.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSliderSection(
                  label: 'Height',
                  icon: Icons.height,
                  value: _currentHeight,
                  min: 120,
                  max: 220,
                  unit: 'cm',
                  onChanged: (value) {
                    setState(() {
                      _currentHeight = value.roundToDouble();
                      heightController.text = value.round().toString();
                    });
                  },
                ),
                SizedBox(height: 15),
                _buildSliderSection(
                  label: 'Weight',
                  icon: Icons.monitor_weight,
                  value: _currentWeight,
                  min: 30,
                  max: 200,
                  unit: 'kg',
                  onChanged: (value) {
                    setState(() {
                      _currentWeight = value.roundToDouble();
                      weightController.text = value.round().toString();
                    });
                  },
                ),
                SizedBox(height: 20), // Increased from previous spacing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.close,
                      label: 'Cancel',
                      color: Colors.grey,
                      onPressed: () => Navigator.pop(context),
                    ),
                    _buildActionButton(
                      icon: Icons.save,
                      label: 'Save',
                      color: TColor.primary,
                      onPressed: () async {
                        try {
                          final newHeight = double.parse(heightController.text);
                          final newWeight = double.parse(weightController.text);

                          await _updateMeasurementsInFirestore(
                              newHeight, newWeight);
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Error updating measurements: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSection({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TColor.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: TColor.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: TColor.primary),
              SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: TColor.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: TColor.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${value.round()} $unit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: TColor.primary,
              inactiveTrackColor: TColor.primary.withOpacity(0.2),
              thumbColor: TColor.primary,
              overlayColor: TColor.primary.withOpacity(0.2),
              valueIndicatorColor: TColor.primary,
              valueIndicatorTextStyle: TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round(),
              label: value.round().toString(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> _updateMeasurementsInFirestore(
      double newHeight, double newWeight) async {
    try {
      print(
          'Attempting to update measurements: Height=$newHeight, Weight=$newWeight, Username=${widget.username}');

      // Check if username is valid
      if (widget.username.isEmpty) {
        print('Error: Username is empty');
        throw Exception('Username is empty, cannot update profile');
      }

      // First update user profile document
      await _firestore.collection('user_profiles').doc(widget.username).update({
        'height': newHeight,
        'weight': newWeight,
      });

      print('User profile updated successfully');

      // Then add to history collection
      final historyEntry = WeightHistoryModel(
        uid: widget.username,
        weight: newWeight,
        height: newHeight,
        dateTime: DateTime.now(),
      );

      // Convert to JSON and verify
      final historyJson = historyEntry.toJson();
      print('History entry created: $historyJson');

      // Add to Firestore
      DocumentReference historyRef =
          await _firestore.collection('weight_history').add(historyJson);
      print('History entry saved with ID: ${historyRef.id}');

      setState(() {
        userHeight = newHeight;
        userWeight = newWeight;
        weightHistory[DateTime.now()] = newWeight;
      });

      if (widget.onWeightUpdate != null) {
        widget.onWeightUpdate!(newWeight);
      }

      print(
          'Measurements updated successfully: Height=$newHeight, Weight=$newWeight');

      // Reload history to confirm changes
      await _loadWeightHistory();
    } catch (e) {
      print('Error updating measurements in Firestore: $e');
      throw e; // Re-throw to be caught by the caller
    }
  }

  Future<void> _loadWeightHistory() async {
    try {
      print('Loading weight history for user: ${widget.username}');

      // Temporary fix: Get all entries for this user without ordering
      final historyDocs = await _firestore
          .collection('weight_history')
          .where('uid', isEqualTo: widget.username)
          .get();

      print('Found ${historyDocs.docs.length} weight history records');

      setState(() {
        weightHistory.clear();
        // Process the documents
        for (var doc in historyDocs.docs) {
          try {
            final entry = WeightHistoryModel.fromJson(doc.data());
            weightHistory[entry.dateTime] = entry.weight;
          } catch (e) {
            print('Error processing history entry: $e');
          }
        }

        // Sort the entries locally after retrieving them
        // (This doesn't require a Firestore index)
      });

      print('Weight history loaded successfully');
    } catch (e) {
      print('Error loading weight history: $e');
    }
  }

  Future<void> clearHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear History'),
        content: Text('Are you sure you want to clear all weight entries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Delete all weight history documents for this user
                final batch = _firestore.batch();
                final historyDocs = await _firestore
                    .collection('weight_history')
                    .where('uid', isEqualTo: widget.username)
                    .get();

                for (var doc in historyDocs.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();

                setState(() {
                  weightHistory.clear();
                  weightHistory[DateTime.now()] = userWeight;
                });
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error clearing history: $e')),
                );
              }
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBMICard() {
    return Container(
      padding: EdgeInsets.all(15), // Reduced padding
      margin: EdgeInsets.only(bottom: 15), // Reduced margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100, // Reduced size
                          height: 100, // Reduced size
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: getBMIColor(calculateBMI()),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  calculateBMI().toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 28, // Adjusted font size
                                    fontWeight: FontWeight.bold,
                                    color: TColor.primary,
                                  ),
                                ),
                                Text(
                                  'BMI',
                                  style: TextStyle(
                                    fontSize: 14, // Adjusted font size
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: Size(110, 110), // Adjusted size
                          painter: BMIArcPainter(
                            progress: (calculateBMI() - 15) / 25,
                            color: getBMIColor(calculateBMI()),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10), // Reduced spacing
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: getBMIColor(calculateBMI()).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: getBMIColor(calculateBMI()),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        getBMICategory(calculateBMI()),
                        style: TextStyle(
                          fontSize: 14, // Adjusted font size
                          fontWeight: FontWeight.bold,
                          color: getBMIColor(calculateBMI()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 15), // Reduced spacing
              Expanded(
                child: Column(
                  children: [
                    _buildStatCard(
                      icon: Icons.height,
                      label: 'Height',
                      value: '${userHeight.toStringAsFixed(1)} cm',
                      onEdit: () => updateMeasurements(),
                    ),
                    SizedBox(height: 10), // Reduced spacing
                    _buildStatCard(
                      icon: Icons.monitor_weight,
                      label: 'Weight',
                      value: '${userWeight.toStringAsFixed(1)} kg',
                      onEdit: () => updateMeasurements(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    // Format the value to remove decimals if it contains a number
    String displayValue = value;
    if (value.contains('.')) {
      final numValue = double.tryParse(value.split(' ')[0]);
      if (numValue != null) {
        displayValue = '${numValue.round()} ${value.split(' ')[1]}';
      }
    }

    return Container(
      padding: EdgeInsets.all(10), // Reduced padding
      decoration: BoxDecoration(
        color: TColor.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TColor.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6), // Reduced padding
            decoration: BoxDecoration(
              color: TColor.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: TColor.primary, size: 16), // Reduced size
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColor.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 14), // Reduced size
            color: TColor.primary,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TColor.white),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (context) => HomeView(
                      username: widget.username, // Pass username back
                    )),
          ),
        ),
        backgroundColor: TColor.primary,
        centerTitle: true,
        elevation: 10.0,
        title: Text(
          "Weight History",
          style: TextStyle(
              color: TColor.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBMICard(),
            _buildWeightHistoryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightHistoryCard() {
    var sortedEntries = weightHistory.entries.toList()
      ..sort((b, a) => a.key.compareTo(b.key)); // Sort by date, newest first

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weight History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: TColor.primary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red),
                onPressed: clearHistory,
              ),
            ],
          ),
          SizedBox(height: 10),
          weightHistory.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No weight history available',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: sortedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = sortedEntries[index];
                    final date = entry.key;
                    final weight = entry.value;
                    final isLatest = index == 0;

                    // Calculate weight change from previous entry
                    double? change;
                    if (index < sortedEntries.length - 1) {
                      change = weight - sortedEntries[index + 1].value;
                    }

                    return Dismissible(
                      key: Key(date.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        setState(() {
                          weightHistory.remove(date);
                        });
                      },
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              '${weight.toStringAsFixed(1)} kg / ${userHeight.toStringAsFixed(1)} cm',
                              style: TextStyle(
                                fontWeight: isLatest
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: isLatest ? 18 : 16,
                              ),
                            ),
                            if (change != null) ...[
                              SizedBox(width: 8),
                              Text(
                                '(${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg)',
                                style: TextStyle(
                                  color: change > 0
                                      ? Colors.orange
                                      : Colors.orange,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy - HH:mm').format(date),
                          style: TextStyle(fontSize: 14),
                        ),
                        trailing: isLatest
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: TColor.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Latest',
                                  style: TextStyle(
                                    color: TColor.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
