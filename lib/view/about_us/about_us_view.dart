import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../../common/color_extension.dart';

class AboutUsView extends StatefulWidget {
  const AboutUsView({super.key});

  @override
  State<AboutUsView> createState() => _AboutUsViewState();
}

class _AboutUsViewState extends State<AboutUsView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

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

  Widget _buildTeamMemberCard(String name, String role, String imageAsset) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
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
        child: Row(
          children: [
            // Profile image
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TColor.primary.withOpacity(0.7),
                    TColor.primary,
                  ],
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: TColor.primary.withOpacity(0.2),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: Icon(
                  Icons.person,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name and role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TColor.primary,
                      fontFamily: 'Quicksand',
                    ),
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 12,
                      color: TColor.secondaryText,
                      fontFamily: 'Quicksand',
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

  Widget _buildCreditsSection(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: TColor.primary,
              fontFamily: 'Quicksand',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: TColor.secondaryText,
              fontFamily: 'Quicksand',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            // Background with gradient header
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
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
                // App Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
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

                      // Title
                      Text(
                        "About Us",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Quicksand',
                          letterSpacing: 0.5,
                        ),
                      ),

                      // Empty container for symmetry
                      Container(
                        width: 40,
                      ),
                    ],
                  ),
                ),

                // Logo and App Name
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      // Logo
                      Image.asset(
                        "assets/img/GRIT.png",
                        height: 50,
                        fit: BoxFit.contain,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      // Subtitle
                      Text(
                        "Fitness for Everyone",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                          fontFamily: 'Quicksand',
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 30),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Our Mission section
                          Padding(
                            padding: const EdgeInsets.only(left: 5, bottom: 15),
                            child: Text(
                              "Our Mission",
                              style: TextStyle(
                                color: TColor.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Quicksand',
                              ),
                            ),
                          ),

                          Container(
                            margin: const EdgeInsets.only(bottom: 25),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Text(
                              "At GRIT, our goal is to make fitness engaging, personalized, and accessible for everyone. We combine gamification and smart recommendations to turn workouts into a fun challenge, helping users stay motivated and track their progress over time—all without needing a gym. Whether you're a beginner or getting back on track, GRIT is here to help you build strength, stay consistent, and achieve your fitness goals at your own pace.",
                              style: TextStyle(
                                fontSize: 14,
                                color: TColor.secondaryText,
                                fontFamily: 'Quicksand',
                                height: 1.6,
                              ),
                            ),
                          ),

                          // Team section header
                          Padding(
                            padding: const EdgeInsets.only(left: 5, bottom: 15),
                            child: Text(
                              "Our Team",
                              style: TextStyle(
                                color: TColor.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Quicksand',
                              ),
                            ),
                          ),

                          // Team members
                          _buildTeamMemberCard(
                              "Erice Justine P. Baay", "Programmer", ""),
                          _buildTeamMemberCard(
                              "Princess A. Moreno", "Team Member", ""),
                          _buildTeamMemberCard(
                              "Yves Frank C. Yabes", "Team Member", ""),

                          const SizedBox(height: 20),

                          // Credits section
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 5, bottom: 15, top: 15),
                            child: Text(
                              "Special Credits",
                              style: TextStyle(
                                color: TColor.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Quicksand',
                              ),
                            ),
                          ),

                          _buildCreditsSection("Pre-Assessment Questionnaire",
                              "Special thanks to Mr. Denver Asuncion, a professional gym instructor, for developing the pre-assessment questions used in this application."),

                          // App version
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                "Version 1.0.0",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TColor.secondaryText.withOpacity(0.7),
                                  fontFamily: 'Quicksand',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
