import 'package:fitness_app/common_widgets/select_datetime.dart';
import 'package:fitness_app/model/weight_history_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // Add this import for min function
import '../../common/color_extension.dart';
import '../../common/round_button.dart';
import '../../model/user_profile_model.dart';

import '../../common_widgets/fitness_level_selector.dart';
import '../../common_widgets/select_picker.dart';
import '../home/home_view.dart';
import 'step2_view.dart';

class Step3View extends StatefulWidget {
  final String username;
  final int initialFitnessLevel;

  const Step3View({
    Key? key,
    required this.username,
    this.initialFitnessLevel = 0,
  }) : super(key: key);

  @override
  State<Step3View> createState() => _Step3ViewState();
}

class _Step3ViewState extends State<Step3View> {
  late var selectIndex = widget.initialFitnessLevel;

  DateTime? selectDate;
  String? selectHeight;
  String? selectWeight;
  bool isMale = true;

  List<String> generateHeightList() {
    return List.generate(500, (index) => "${index + 1} cm");
  }

  List<String> generateWeightList() {
    return List.generate(500, (index) => "${index + 1} kg");
  }

  Future<void> _saveUserProfile() async {
    try {
      if (selectHeight == null || selectWeight == null || selectDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill in all required fields')),
        );
        return;
      }

      // Ensure username is valid
      if (widget.username.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Username is invalid. Please go back and enter a valid username.')),
        );
        return;
      }

      // Debug the username to make sure it's correct
      print('Saving profile for username: ${widget.username}');

      // Create user profile
      final userProfile = UserProfileModel(
        uid: widget.username,
        birthDate: selectDate!,
        weight: selectWeight!,
        height: selectHeight!,
        isMale: isMale,
        fitnessLevel: selectIndex,
      );

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(color: TColor.primary),
          );
        },
      );

      // Save to Firestore - set the doc id explicitly as the username
      final userDocRef = FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(widget.username);

      await userDocRef.set(userProfile.toJson());

      // Create initial weight history entry with auto-generated ID
      final weightHistoryEntry = WeightHistoryModel(
        uid: widget.username,
        weight: double.parse(selectWeight!.replaceAll(RegExp(r'[^0-9.]'), '')),
        height: double.parse(selectHeight!.replaceAll(RegExp(r'[^0-9.]'), '')),
        dateTime: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('weight_history')
          .add(weightHistoryEntry.toJson());

      // Navigate to home view
      if (mounted) {
        // Remove loading indicator
        Navigator.pop(context);

        // Navigate to home view and clear stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeView(username: widget.username),
          ),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      print('Error saving profile: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        // Dismiss loading indicator if it's showing
        if (Navigator.canPop(context)) Navigator.pop(context);

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error saving profile: ${e.toString().substring(0, min(50, e.toString().length))}...'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: TColor.white,
          centerTitle: true,
          leading: IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => Step2View(
                          username: widget.username, // Pass username here
                        )),
                (route) => false,
              );
            },
            icon: Image.asset(
              "assets/img/back.png",
              width: 25,
              height: 25,
            ),
          ),
          title: Text(
            "Step 3 of 3",
            style: TextStyle(
              color: TColor.primary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "Personal Details",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TColor.secondaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  "Let us know about you to speed up the result, Get fit with your personal workout plan!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: TColor.secondaryText, fontSize: 16),
                ),
              ),
              SizedBox(height: media.width * 0.05),
              Divider(color: TColor.divider, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: SelectDatetime(
                  title: "Birthday",
                  didChange: (newDate) {
                    setState(() {
                      selectDate = newDate;
                    });
                  },
                  selectDate: selectDate,
                ),
              ),
              Divider(color: TColor.divider, height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: SelectPicker(
                  allVal: generateHeightList(),
                  selectVal: selectHeight,
                  title: "Height",
                  didChange: (newVal) {
                    setState(() {
                      selectHeight = newVal;
                    });
                  },
                ),
              ),
              Divider(color: TColor.divider, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: SelectPicker(
                  allVal: generateWeightList(),
                  selectVal: selectWeight,
                  title: "Weight",
                  didChange: (newVal) {
                    setState(() {
                      selectWeight = newVal;
                    });
                  },
                ),
              ),
              Divider(color: TColor.divider, height: 5),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 5, vertical: media.width * 0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Text(
                        "Gender",
                        style: TextStyle(
                            color: TColor.secondaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    CupertinoSegmentedControl<bool>(
                      groupValue: isMale,
                      selectedColor: TColor.primary,
                      unselectedColor: TColor.white,
                      borderColor: TColor.primary,
                      children: const {
                        true: Text(" Male ", style: TextStyle(fontSize: 18)),
                        false: Text(" Female ", style: TextStyle(fontSize: 18))
                      },
                      onValueChanged: (bool isMaleVal) {
                        setState(() {
                          isMale = isMaleVal;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Divider(color: TColor.divider, height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  "Fitness Level",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TColor.secondaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FitnessLevelSelector(
                title: "Beginner",
                subtitle: "You are new to fitness training",
                isSelect: selectIndex == 0,
                onPressed: () {}, // Disable interaction with an empty function
              ),
              FitnessLevelSelector(
                title: "Intermediate",
                subtitle: "You have been training regularly",
                isSelect: selectIndex == 1,
                onPressed: () {}, // Disable interaction with an empty function
              ),
              FitnessLevelSelector(
                title: "Advanced",
                subtitle: "You're fit and ready for an intensive workout plan",
                isSelect: selectIndex == 2,
                onPressed: () {}, // Disable interaction with an empty function
              ),
              const Spacer(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                child: RoundButton(
                  title: "Start",
                  onPressed: _saveUserProfile,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  1,
                  2,
                  3,
                ].map((index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: index == 3
                          ? TColor.primary
                          : TColor.gray.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
