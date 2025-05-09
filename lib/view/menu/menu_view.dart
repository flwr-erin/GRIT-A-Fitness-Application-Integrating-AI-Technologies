import 'package:fitness_app/view/achievements/achievements_view.dart';
import 'package:fitness_app/view/exercise_view.dart';
import 'package:fitness_app/view/training_stats_view.dart';
import 'package:fitness_app/view/weight_view.dart';
import 'package:fitness_app/view/workout_view.dart';
import 'package:fitness_app/view/about_us/about_us_view.dart'; // Import the About Us view
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness_app/view/login/on_boarding_view.dart';
import 'package:fitness_app/view/login/step2_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

import '../../common/color_extension.dart';
import '../home/home_view.dart';

class MenuView extends StatefulWidget {
  final String username;
  const MenuView({super.key, required this.username});

  @override
  State<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<MenuView>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<DocumentSnapshot>? _userProfileStream;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _userProfileStream =
        _firestore.collection('user_profiles').doc(widget.username).snapshots();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Fitness tips collection
  final List<Map<String, dynamic>> fitnessTips = [
    {
      "title": "Hydration",
      "tip":
          "Drink at least 8 glasses of water daily. Hydration improves performance and recovery.",
      "icon": Icons.water_drop,
      "color": Color(0xFF2196F3),
    },
    {
      "title": "Protein Intake",
      "tip":
          "Consume 1.6-2.2g of protein per kg of body weight to optimize muscle growth.",
      "icon": Icons.breakfast_dining,
      "color": Color(0xFFE91E63),
    },
    {
      "title": "Rest Days",
      "tip":
          "Schedule 1-2 rest days weekly. Recovery is when muscles grow stronger.",
      "icon": Icons.hotel,
      "color": Color(0xFF9C27B0),
    },
    {
      "title": "Progressive Overload",
      "tip":
          "Gradually increase weight, reps, or sets to continuously challenge your muscles.",
      "icon": Icons.fitness_center,
      "color": Color(0xFFFF9800),
    },
    {
      "title": "Sleep Quality",
      "tip":
          "Aim for 7-9 hours of quality sleep. Sleep is essential for recovery and hormone regulation.",
      "icon": Icons.nightlight_round,
      "color": Color(0xFF3F51B5),
    },
  ];

  List menuArr = [
    {"name": "Achievements", "icon": Icons.emoji_events, "tag": "9"},
    {
      "name": "Tips",
      "icon": Icons.lightbulb_outline,
      "tag": "10",
      "action": "showTips"
    },
    {"name": "Settings", "icon": Icons.settings, "tag": "11"},
    {"name": "About Us", "icon": Icons.info_outline, "tag": "12"},
  ];

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              color: TColor.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Quicksand',
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              color: TColor.primary,
              fontSize: 16,
              fontFamily: 'Quicksand',
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: TColor.primary),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: TColor.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Quicksand',
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: TColor.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Quicksand',
                ),
              ),
              onPressed: () async {
                // Clear login state
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('username');

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const OnBoardingView()),
                  (route) => false,
                );
              },
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        );
      },
    );
  }

  void _showTipsPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Fitness Tips",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Quicksand',
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 3.0,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tips Cards
                Expanded(
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.85),
                    itemCount: fitnessTips.length,
                    itemBuilder: (context, index) {
                      final tip = fitnessTips[index];
                      return _buildTipCard(tip);
                    },
                  ),
                ),

                // Page indicator
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      fitnessTips.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTipCard(Map<String, dynamic> tip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (tip["color"] as Color).withOpacity(0.9),
            (tip["color"] as Color).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: (tip["color"] as Color).withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              right: -30,
              top: -30,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon header
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      tip["icon"] as IconData,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    tip["title"],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Quicksand',
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Divider
                  Container(
                    width: 50,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Tip text
                  Expanded(
                    child: Text(
                      tip["tip"],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        height: 1.5,
                        fontFamily: 'Quicksand',
                      ),
                    ),
                  ),

                  // "Swipe" hint at bottom
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swipe,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Swipe for more tips",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontFamily: 'Quicksand',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Settings',
            style: TextStyle(
              color: TColor.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Quicksand',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: TColor.primary.withOpacity(0.1),
                  child: Icon(Icons.fitness_center, color: TColor.primary),
                ),
                title: const Text(
                  'Update Fitness Assessment',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontFamily: 'Quicksand'),
                ),
                subtitle: Text(
                  'Retake your fitness quiz to update your training level',
                  style: TextStyle(
                    fontSize: 13,
                    color: TColor.secondaryText,
                    fontFamily: 'Quicksand',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAssessmentConfirmation(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: TColor.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Quicksand',
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        );
      },
    );
  }

  void _showAssessmentConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Retake Assessment',
            style: TextStyle(
              color: TColor.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Quicksand',
            ),
          ),
          content: Text(
            'You\'re about to retake your fitness assessment. This will help update your training program based on your current fitness level. Would you like to proceed?',
            style: TextStyle(
              color: TColor.secondaryText,
              fontSize: 16,
              fontFamily: 'Quicksand',
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: TColor.primary),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: TColor.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Quicksand',
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: TColor.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Quicksand',
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Step2View(
                      username: widget.username,
                      isUpdate: true, // Set this to true for updates
                    ),
                  ),
                );
              },
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        );
      },
    );
  }

  Widget _buildProfileStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(Map mObj) {
    return InkWell(
      onTap: () {
        if (mObj["action"] == "showTips") {
          _showTipsPopup(context);
          return;
        }

        switch (mObj["tag"].toString()) {
          case "1":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HomeView(username: widget.username),
              ),
            );
            break;
          case "2":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeightView(
                  username: widget.username,
                  initialHeight: 0.0,
                ),
              ),
            );
            break;
          case "3":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WorkoutView(
                  username: '',
                  userId: '',
                ),
              ),
            );
            break;
          case "4":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrainingStatsView(
                  username: widget.username,
                ),
              ),
            );
            break;
          case "8":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExerciseView(
                  username: widget.username,
                ),
              ),
            );
            break;
          case "9":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AchievementsView(
                  username: widget.username,
                ),
              ),
            );
            break;
          case "11": // Settings menu item
            _showSettingsOptions(context);
            break;
          case "12": // About Us menu item
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutUsView(),
              ),
            );
            break;
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.95),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TColor.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      mObj["icon"] as IconData,
                      color: TColor.primary,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mObj["name"],
                    style: TextStyle(
                      fontSize: 16,
                      color: TColor.primary.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Quicksand',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            // Background with gradient
            Container(
              height: media.height * 0.35, // Slightly taller header
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TColor.primary,
                    TColor.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: TColor.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),

            Column(
              children: [
                // Header Section
                Container(
                  height: media.height * 0.35,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar with back and logout button
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.of(context).pop();
                                  } else {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            HomeView(username: widget.username),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),

                            // GRIT Logo centered
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Image.asset(
                                "assets/img/GRIT.png",
                                height: 30,
                                fit: BoxFit.contain,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),

                            // Logout Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _handleLogout(context),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Profile Data
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: _userProfileStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              );
                            }

                            var userProfile =
                                snapshot.data?.data() as Map<String, dynamic>?;
                            String height =
                                userProfile?['height']?.toString() ?? 'N/A';
                            String weight =
                                userProfile?['weight']?.toString() ?? 'N/A';
                            bool isMale = userProfile?['isMale'] ?? true;

                            return Center(
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // User Avatar with Gender Icon
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withOpacity(0.9),
                                                Colors.white.withOpacity(0.7),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Padding(
                                              padding: const EdgeInsets.all(15),
                                              child: Image.asset(
                                                "assets/img/GRIT.png",
                                                fit: BoxFit.contain,
                                                color: TColor.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color:
                                                TColor.primary.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            isMale ? Icons.male : Icons.female,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),

                                    // Username
                                    Text(
                                      widget.username.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(1, 1),
                                            blurRadius: 3.0,
                                            color: Color.fromARGB(100, 0, 0, 0),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 15),

                                    // Height and Weight Cards
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildProfileStat(
                                          Icons.height,
                                          "HEIGHT",
                                          height,
                                        ),
                                        const SizedBox(width: 20),
                                        _buildProfileStat(
                                          Icons.monitor_weight_outlined,
                                          "WEIGHT",
                                          weight,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Grid Section
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 5, bottom: 15),
                          child: Text(
                            "Menu",
                            style: TextStyle(
                              color: TColor.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Quicksand',
                            ),
                          ),
                        ),

                        // Grid Menu
                        Expanded(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: menuArr.length,
                            itemBuilder: (context, index) {
                              var mObj = menuArr[index] as Map? ?? {};
                              return _buildMenuCard(mObj);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
