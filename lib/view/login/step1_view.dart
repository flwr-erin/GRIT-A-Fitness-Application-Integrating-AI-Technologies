import 'package:flutter/material.dart';

import '../../common/color_extension.dart';
import '../../common/round_button.dart';
import 'step2_view.dart';

class Step1View extends StatefulWidget {
  final String username; // Add this line

  const Step1View({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  State<Step1View> createState() => _Step1ViewState();
}

class _Step1ViewState extends State<Step1View> {
  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.sizeOf(context);
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: TColor.white,
          centerTitle: true,
          title: Text(
            "Step 1 of 3",
            style: TextStyle(
                color: TColor.primary,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
            child: Column(
          children: [
            const Spacer(),
            Image.asset(
              "assets/img/step_1.png",
              width: media.width * 0.6,
              height: media.width * 0.6,
              fit: BoxFit.contain,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                "Welcome to\nGrit Fitness Application",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: TColor.secondaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              "Personalized Workouts will help you\ngain strength, get in better shape and\nembrace a healthy lifestyle",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: TColor.secondaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w300),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
              child: RoundButton(
                title: "Get Started",
                onPressed: _navigateToStep2,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                1,
                2,
                3,
              ].map((p0bj) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: 1 == p0bj
                        ? TColor.primary
                        : TColor.gray.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(
              height: 15,
            )
          ],
        )),
      ),
    );
  }

  void _navigateToStep2() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => Step2View(
          username: widget.username, // Pass username to Step2View
        ),
      ),
      (route) => false,
    );
  }
}
