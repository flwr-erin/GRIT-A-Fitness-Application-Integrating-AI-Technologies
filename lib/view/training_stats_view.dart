import 'dart:async';
import 'package:flutter/material.dart';
import '../../common/color_extension.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingStatsView extends StatefulWidget {
  final String username;
  const TrainingStatsView({super.key, required this.username});

  @override
  State<TrainingStatsView> createState() => _TrainingStatsViewState();
}

class _TrainingStatsViewState extends State<TrainingStatsView> {
  // Updated rank progression constants
  final Map<String, Map<String, dynamic>> rankRequirements = {
    'Beginner': {'maxLevel': 10, 'nextRank': 'Novice'},
    'Novice': {'maxLevel': 20, 'nextRank': 'Intermediate'},
    'Intermediate': {'maxLevel': 40, 'nextRank': 'Advanced'},
    'Advanced': {'maxLevel': 60, 'nextRank': 'Expert'},
    'Expert': {'maxLevel': 80, 'nextRank': 'Master'},
    'Master': {'maxLevel': 100, 'nextRank': null},
  };

  // Firestore instance to load actual user data
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? userId;
  bool isLoading = true;

  final List<Map<String, dynamic>> muscleGroups = [
    {
      "title": "Chest",
      "images": ["chest.png"],
      "description":
          "The chest muscles, or pectorals, are essential for pushing movements and arm control. They play a crucial role in upper body strength and stability.",
      "rank": "Beginner",
      "level": 1,
      "progress": 1
    },
    {
      "title": "Back",
      "images": ["lower back.png", "upper back.png"],
      "description":
          "The back muscles help maintain posture and are crucial for pulling movements. They support the spine and contribute to overall body strength.",
      "rank": "Beginner",
      "level": 1,
      "progress": 0.1
    },
    {
      "title": "Arms",
      "images": ["biceps.png", "triceps.png"],
      "description":
          "Arm muscles include biceps for pulling and triceps for pushing movements. They are vital for various daily activities and upper body exercises.",
      "rank": "Beginner",
      "level": 1,
      "progress": 0.2
    },
    {
      "title": "Shoulders",
      "images": ["shoulder.png"],
      "description":
          "Shoulders enable arm rotation and are vital for overhead movements. They provide stability and strength for lifting and carrying tasks.",
      "rank": "Beginner",
      "level": 1,
      "progress": 0.15
    },
    {
      "title": "Legs",
      "images": ["legs.png", "legs back.png"],
      "description":
          "Leg muscles are fundamental for movement, stability, and overall strength. They support walking, running, and jumping activities.",
      "rank": "Beginner",
      "level": 1,
      "progress": 0.25
    },
    {
      "title": "Abdominals",
      "images": ["abdominals.png"],
      "description":
          "Core muscles provide stability and are essential for all body movements. They support the spine and help maintain balance and posture.",
      "rank": "Beginner",
      "level": 1,
      "progress": 0.4
    },
  ];

  // Add muscle categories map for displaying targeted muscles
  final Map<String, List<String>> muscleCategories = {
    'chest': ['chest'],
    'back': ['middle back', 'lower back', 'lats', 'traps', 'neck'],
    'arms': ['biceps', 'triceps', 'forearms'],
    'abdominals': ['abdominals'],
    'legs': [
      'hamstrings',
      'abductors',
      'quadriceps',
      'calves',
      'glutes',
      'adductors'
    ],
    'shoulders': ['shoulders'],
  };

  String getNextRank(String currentRank, int currentLevel) {
    var requirement = rankRequirements[currentRank];
    if (requirement != null && currentLevel >= requirement['maxLevel']) {
      return requirement['nextRank'] ?? currentRank;
    }
    return rankRequirements[currentRank]?['nextRank'] ?? currentRank;
  }

  double calculateLevelProgress(String rank, int level) {
    var requirement = rankRequirements[rank];
    if (requirement == null) return 0.0;

    for (var group in muscleGroups) {
      if (group["rank"] == rank && group["level"] == level) {
        return (group["progress"] as double).clamp(0.0, 1.0);
      }
    }

    return 0.0;
  }

  String getPreviousRank(String rank) {
    switch (rank) {
      case 'Novice':
        return 'Beginner';
      case 'Intermediate':
        return 'Novice';
      case 'Advanced':
        return 'Intermediate';
      case 'Expert':
        return 'Advanced';
      case 'Master':
        return 'Expert';
      default:
        return 'Beginner';
    }
  }

  int currentPage = 0;

  String getRankColor(String rank) {
    switch (rank.toLowerCase()) {
      case 'beginner':
        return '#8E8E8E';
      case 'novice':
        return '#CD7F32';
      case 'intermediate':
        return '#4682B4';
      case 'advanced':
        return '#FFD700';
      case 'expert':
        return '#800080';
      case 'master':
        return '#FF4500';
      default:
        return '#8E8E8E';
    }
  }

  Map<String, int> currentImageIndices = {};
  Timer? imageTimer;

  @override
  void initState() {
    super.initState();
    for (var group in muscleGroups) {
      currentImageIndices[group["title"]] = 0;
    }
    _loadUserData();
    startImageTimer();
  }

  Future<void> _loadUserData() async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        userId = userQuery.docs.first.id;
        await _loadMuscleStats();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMuscleStats() async {
    if (userId == null) return;

    try {
      final docRef =
          await _firestore.collection('user_stats').doc(userId).get();

      if (docRef.exists) {
        final data = docRef.data();
        if (data != null && data.containsKey('muscleStats')) {
          final stats = data['muscleStats'] as Map<String, dynamic>;

          setState(() {
            for (var i = 0; i < muscleGroups.length; i++) {
              String muscleKey =
                  muscleGroups[i]["title"].toString().toLowerCase();

              if (stats.containsKey(muscleKey)) {
                int level = (stats[muscleKey]['level'] as num).toInt();
                double progress =
                    (stats[muscleKey]['progress'] as num).toDouble();

                muscleGroups[i]["level"] = level;
                muscleGroups[i]["progress"] = progress;
                muscleGroups[i]["rank"] = getMuscleRank(level);
              }
            }
          });
        }
      }
    } catch (e) {
      print('Error loading muscle stats: $e');
    }
  }

  String getMuscleRank(int level) {
    if (level >= 100) return 'Master';
    if (level >= 80) return 'Expert';
    if (level >= 60) return 'Advanced';
    if (level >= 40) return 'Intermediate';
    if (level >= 20) return 'Novice';
    return 'Beginner';
  }

  @override
  void dispose() {
    imageTimer?.cancel();
    super.dispose();
  }

  void startImageTimer() {
    imageTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      setState(() {
        for (var group in muscleGroups) {
          if ((group["images"] as List).length > 1) {
            String title = group["title"];
            int currentIndex = currentImageIndices[title] ?? 0;
            currentImageIndices[title] =
                (currentIndex + 1) % (group["images"] as List).length;
          }
        }
      });
    });
  }

  Widget buildImageContainer(Map<String, dynamic> muscleGroup) {
    List<String> images = muscleGroup["images"];
    String title = muscleGroup["title"];
    int currentIndex = currentImageIndices[title] ?? 0;

    return Container(
      height: 160, // Reduced height to prevent overflow
      child: Center(
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Image.asset(
            "assets/img/${images[currentIndex]}",
            key: ValueKey<String>("${title}_${images[currentIndex]}"),
            fit: BoxFit.contain,
            width: 140, // Smaller width
            height: 160, // Smaller height
          ),
        ),
      ),
    );
  }

  Widget buildProgressText(int level, String rank) {
    if (rank == "Master" && level >= 100) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber[400]!,
              Colors.amber[700]!,
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.amber[300]!,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            Icons.workspace_premium,
            color: Colors.white,
            size: 22,
          ),
          SizedBox(width: 8),
          Text(
            "MASTERY ACHIEVED",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    double progress = 0.0;
    for (var group in muscleGroups) {
      if (group["rank"] == rank && group["level"] == level) {
        progress = (group["progress"] as double).clamp(0.0, 1.0);
        break;
      }
    }

    int progressPercent = (progress * 100).round();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Color(int.parse('0xFF${getRankColor(rank).substring(1)}'))
              .withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          Icons.arrow_circle_up,
          color: Color(int.parse('0xFF${getRankColor(rank).substring(1)}')),
          size: 16,
        ),
        SizedBox(width: 5),
        Text(
          "$progressPercent% to Level ${level + 1}",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ]),
    );
  }

  Widget buildEnhancedProgressBar(String rank, int level) {
    Color rankColor =
        Color(int.parse('0xFF${getRankColor(rank).substring(1)}'));
    bool isMaxLevel = rank == "Master" && level >= 100;

    double progressValue = 0.0;
    for (var group in muscleGroups) {
      if (group["rank"] == rank && group["level"] == level) {
        progressValue = (group["progress"] as double).clamp(0.0, 1.0);
        break;
      }
    }

    // If max level, set progress to 100%
    if (isMaxLevel) {
      progressValue = 1.0;
    }

    return Stack(
      children: [
        Container(
          height: 20,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[300],
            border: Border.all(
              color: Colors.grey[400]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        Container(
          height: 20,
          width: MediaQuery.of(context).size.width *
              (isMaxLevel ? 0.9 : progressValue * 0.7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isMaxLevel
                  ? [
                      Colors.amber[400]!,
                      Colors.amber[700]!,
                    ]
                  : [
                      rankColor.withOpacity(0.7),
                      rankColor,
                    ],
            ),
            border: progressValue > 0
                ? Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              5,
              (index) => progressValue * 5 > index
                  ? Container(
                      width: 2,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  : SizedBox(),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              "${(progressValue * 100).round()}%",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: progressValue > 0.5 ? Colors.white : Colors.black87,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTargetedMuscles(String muscleGroup, Color rankColor) {
    String groupKey = muscleGroup.toLowerCase();
    List<String> muscles = muscleCategories[groupKey] ?? [];

    // Special case for legs which have more targets
    bool isLegs = groupKey == 'legs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                rankColor.withOpacity(0.9),
                rankColor.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.3),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hexagon,
                size: 14,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                "MUSCLE TARGETS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.8,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLegs ? 3 : 2,
              childAspectRatio: isLegs ? 3.5 : 3.5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: muscles.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rankColor.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    capitalize(muscles[index]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isLegs ? 9 : 15,
                      fontWeight: FontWeight.w500,
                      color: rankColor.withOpacity(0.8),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String capitalize(String text) {
    if (text.isEmpty) return text;

    final words = text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    });

    return capitalizedWords.join(' ');
  }

  IconData getIconForMuscle(String muscle) {
    switch (muscle) {
      case 'chest':
        return Icons.accessibility_new;
      case 'middle back':
      case 'lower back':
        return Icons.airline_seat_flat;
      case 'lats':
      case 'traps':
        return Icons.swap_horiz;
      case 'neck':
        return Icons.arrow_upward;
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return Icons.fitness_center;
      case 'abdominals':
        return Icons.straighten;
      case 'hamstrings':
      case 'quadriceps':
      case 'calves':
      case 'adductors':
      case 'abductors':
        return Icons.directions_walk;
      case 'glutes':
        return Icons.airline_seat_recline_normal;
      case 'shoulders':
        return Icons.architecture;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TColor.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: TColor.primary,
        centerTitle: true,
        elevation: 10.0,
        shadowColor: Colors.black.withOpacity(0.5),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 22),
            SizedBox(width: 8),
            Text(
              "MUSCLE STATS",
              style: TextStyle(
                color: TColor.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: TColor.primary),
                  SizedBox(height: 15),
                  Text(
                    "Loading your stats...",
                    style: TextStyle(
                      color: TColor.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TColor.primary.withOpacity(0.1),
                    Colors.white.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.85,
                          child: PageView.builder(
                            onPageChanged: (index) {
                              setState(() {
                                currentPage = index;
                              });
                            },
                            itemCount: muscleGroups.length,
                            itemBuilder: (context, index) {
                              Color rankColor = Color(int.parse(
                                  '0xFF${getRankColor(muscleGroups[index]["rank"]).substring(1)}'));

                              return AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                margin: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16), // Smaller margin
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: rankColor.withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: rankColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Column(children: [
                                  Stack(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 10), // Smaller padding
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              rankColor.withOpacity(0.8),
                                              rankColor,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(18),
                                            topRight: Radius.circular(18),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: rankColor.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            muscleGroups[index]["title"]!
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 18, // Smaller font
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1.2,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 15,
                                        top: 14,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: rankColor,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "LV ${muscleGroups[index]["level"]}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: rankColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics:
                                          BouncingScrollPhysics(), // Changed to enable scrolling if needed
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12, // Smaller padding
                                          vertical: 8, // Smaller padding
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            buildImageContainer(
                                                muscleGroups[index]),

                                            // About section with larger text
                                            Container(
                                              margin:
                                                  EdgeInsets.only(bottom: 10),
                                              padding: EdgeInsets.all(12),
                                              height:
                                                  130, // Keeping the same height
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: rankColor
                                                      .withOpacity(0.3),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 5,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 5),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment
                                                            .centerLeft,
                                                        end: Alignment
                                                            .centerRight,
                                                        colors: [
                                                          rankColor
                                                              .withOpacity(0.7),
                                                          rankColor
                                                              .withOpacity(0.3),
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      "MUSCLE INFO",
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        letterSpacing: 0.8,
                                                        shadows: [
                                                          Shadow(
                                                            color:
                                                                Colors.black26,
                                                            blurRadius: 2,
                                                            offset:
                                                                Offset(0, 1),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Expanded(
                                                    child:
                                                        SingleChildScrollView(
                                                      physics:
                                                          BouncingScrollPhysics(),
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                top: 2),
                                                        child: Text(
                                                          muscleGroups[index]
                                                              ["description"]!,
                                                          style: TextStyle(
                                                            fontSize:
                                                                14, // Increased from 13 to 15
                                                            color: Colors
                                                                .grey.shade800,
                                                            height: 1.3,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Targeted Muscles Section with improved visual hierarchy
                                            Container(
                                              margin:
                                                  EdgeInsets.only(bottom: 10),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                              height: muscleGroups[index]
                                                          ["title"] ==
                                                      "Legs"
                                                  ? 130
                                                  : 110,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: rankColor
                                                      .withOpacity(0.3),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 5,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: buildTargetedMuscles(
                                                  muscleGroups[index]["title"],
                                                  rankColor),
                                            ),
                                            // Level & Rank Card - with gaming style
                                            Container(
                                              padding: EdgeInsets.all(
                                                  15), // Smaller padding
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    rankColor.withOpacity(0.15),
                                                    rankColor.withOpacity(0.25),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: rankColor
                                                      .withOpacity(0.5),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: rankColor
                                                        .withOpacity(0.2),
                                                    blurRadius: 10,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(
                                                        10), // Smaller padding
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: rankColor
                                                              .withOpacity(0.5),
                                                          blurRadius: 10,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                      border: Border.all(
                                                        color: rankColor,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      getRankIcon(
                                                          muscleGroups[index]
                                                              ["rank"]),
                                                      color: rankColor,
                                                      size: 30, // Smaller icon
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          10), // Smaller spacing
                                                  Text(
                                                    muscleGroups[index]["rank"]
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize:
                                                          20, // Smaller font
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: rankColor,
                                                      letterSpacing: 1.0,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.white,
                                                          blurRadius: 10,
                                                          offset: Offset(0, 0),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          15), // Smaller spacing
                                                  buildEnhancedProgressBar(
                                                    muscleGroups[index]["rank"],
                                                    muscleGroups[index]
                                                        ["level"],
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          12), // Smaller spacing
                                                  buildProgressText(
                                                    muscleGroups[index]
                                                        ["level"],
                                                    muscleGroups[index]["rank"],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            },
                          ),
                        ),
                        _buildGamePageIndicator(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  IconData getRankIcon(String rank) {
    switch (rank.toLowerCase()) {
      case 'beginner':
        return Icons.sports_gymnastics;
      case 'novice':
        return Icons.fitness_center;
      case 'intermediate':
        return Icons.bolt;
      case 'advanced':
        return Icons.local_fire_department;
      case 'expert':
        return Icons.star;
      case 'master':
        return Icons.workspace_premium;
      default:
        return Icons.sports_gymnastics;
    }
  }

  Widget _buildGamePageIndicator() {
    return Container(
      padding: EdgeInsets.only(bottom: 10), // Smaller padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          muscleGroups.length,
          (index) => GestureDetector(
            onTap: () {
              if (currentPage != index) {
                setState(() {
                  currentPage = index;
                });
              }
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: 3), // Smaller margin
              height: 8, // Smaller height
              width: currentPage == index ? 24 : 8, // Smaller width
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: currentPage == index
                    ? Color(int.parse(
                        '0xFF${getRankColor(muscleGroups[index]["rank"]).substring(1)}'))
                    : Colors.grey.withOpacity(0.3),
                boxShadow: currentPage == index
                    ? [
                        BoxShadow(
                          color: Color(int.parse(
                                  '0xFF${getRankColor(muscleGroups[index]["rank"]).substring(1)}'))
                              .withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: TColor.primary,
          ),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getCurrentDay() {
    int currentDay = DateTime.now().weekday;
    List<String> days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return days[(currentDay % 7)];
  }
}
