import 'package:flutter/material.dart';
import '../../common/color_extension.dart';
import '../../common/round_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'step1_view.dart';
import 'step3_view.dart';

class Step2View extends StatefulWidget {
  final String username;
  final bool isUpdate; // New parameter to determine if this is an update

  const Step2View({
    Key? key,
    required this.username,
    this.isUpdate = false, // Default to false for new users
  }) : super(key: key);

  @override
  State<Step2View> createState() => _Step2ViewState();
}

class _Step2ViewState extends State<Step2View> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Map<String, String> _answers = {};

  // Reorganized questions with exactly 5 questions per category
  final List<Map<String, dynamic>> questions = [
    // Physical Activity History - 5 questions
    {
      'category': 'Physical Activity History',
      'question':
          'How many days per week do you engage in structured exercise?',
      'options': {
        'A': '0-1 days',
        'B': '2-3 days',
        'C': '4-5 days',
        'D': '6+ days'
      }
    },
    {
      'category': 'Physical Activity History',
      'question': 'How long do you typically exercise per session?',
      'options': {
        'A': 'Less than 15 minutes',
        'B': '15-30 minutes',
        'C': '30-60 minutes',
        'D': 'More than 60 minutes'
      }
    },
    {
      'category': 'Physical Activity History',
      'question': 'What is the intensity of your usual workouts?',
      'options': {
        'A': 'Light (e.g., walking, casual stretching)',
        'B': 'Moderate (e.g., bodyweight exercises, jogging, yoga)',
        'C': 'Intense (e.g., weightlifting, HIIT, sports)',
        'D': 'Very intense (e.g., advanced strength training, endurance sports)'
      }
    },
    {
      'category': 'Physical Activity History',
      'question':
          'How often do you incorporate strength training in your routines?',
      'options': {
        'A': 'Never',
        'B': 'Occasionally (once a week or less)',
        'C': 'Regularly (2-3 times a week)',
        'D': 'Frequently (4+ times a week)'
      }
    },
    {
      'category': 'Physical Activity History',
      'question': 'How long have you been consistently exercising?',
      'options': {
        'A': 'Just starting out',
        'B': '1-6 months',
        'C': '6-12 months',
        'D': 'More than a year'
      }
    },

    // Cardiovascular Endurance - 5 questions
    {
      'category': 'Cardiovascular Endurance',
      'question': 'How long can you run continuously without stopping?',
      'options': {
        'A': 'Less than 2 minutes',
        'B': '2-10 minutes',
        'C': '10-30 minutes',
        'D': 'More than 30 minutes'
      }
    },
    {
      'category': 'Cardiovascular Endurance',
      'question':
          'How many flights of stairs can you climb before feeling winded?',
      'options': {
        'A': '1-2 flights',
        'B': '3-5 flights',
        'C': '6-10 flights',
        'D': 'More than 10 flights'
      }
    },
    {
      'category': 'Cardiovascular Endurance',
      'question': 'Resting Heart Rate (RHR):',
      'options': {
        'A': '80+ bpm',
        'B': '70-79 bpm',
        'C': '60-69 bpm',
        'D': 'Below 60 bpm'
      }
    },
    {
      'category': 'Cardiovascular Endurance',
      'question': 'How quickly do you recover after intense cardio exercise?',
      'options': {
        'A': 'Takes more than 5 minutes to return to normal breathing',
        'B': '3-5 minutes to recover',
        'C': '1-3 minutes to recover',
        'D': 'Less than 1 minute to recover'
      }
    },
    {
      'category': 'Cardiovascular Endurance',
      'question':
          'What distance can you comfortably walk without getting tired?',
      'options': {
        'A': 'Less than 1 mile',
        'B': '1-3 miles',
        'C': '3-5 miles',
        'D': 'More than 5 miles'
      }
    },

    // Flexibility & Mobility - 5 questions
    {
      'category': 'Flexibility & Mobility',
      'question': 'Can you touch your toes without bending your knees?',
      'options': {
        'A': 'No, not even close',
        'B': 'Just barely',
        'C': 'Yes, comfortably',
        'D': 'Yes, I can place my palms flat on the floor'
      }
    },
    {
      'category': 'Flexibility & Mobility',
      'question': 'Can you perform a deep squat without heel lift?',
      'options': {
        'A': 'No, I fall backward',
        'B': 'Yes, but I feel tightness',
        'C': 'Yes, with ease',
        'D': 'Yes, and I can hold it for more than 30 seconds'
      }
    },
    {
      'category': 'Flexibility & Mobility',
      'question': 'How well can you reach behind your back?',
      'options': {
        'A': 'I can barely reach the middle of my back',
        'B': 'I can reach my shoulder blades',
        'C': 'I can touch between my shoulder blades',
        'D': 'I can clasp my hands between my shoulder blades'
      }
    },
    {
      'category': 'Flexibility & Mobility',
      'question': 'Can you hold a plank position properly?',
      'options': {
        'A': 'Less than 15 seconds',
        'B': '15-30 seconds',
        'C': '30-60 seconds',
        'D': 'More than 60 seconds'
      }
    },
    {
      'category': 'Flexibility & Mobility',
      'question': 'How\'s your ankle mobility?',
      'options': {
        'A': 'Poor - can\'t squat without heel lift',
        'B': 'Limited - slight heel lift needed',
        'C': 'Good - can maintain proper position',
        'D': 'Excellent - full range of motion'
      }
    },

    // Health Status - 5 questions
    {
      'category': 'Health Status',
      'question': 'What is your typical sleep duration per night?',
      'options': {
        'A': 'Less than 6 hours',
        'B': '6-7 hours',
        'C': '7-8 hours',
        'D': 'More than 8 hours'
      }
    },
    {
      'category': 'Health Status',
      'question': 'How would you rate your stress levels?',
      'options': {'A': 'Very High', 'B': 'High', 'C': 'Moderate', 'D': 'Low'}
    },
    {
      'category': 'Health Status',
      'question': 'How many glasses of water do you drink daily?',
      'options': {
        'A': '0-2 glasses',
        'B': '3-5 glasses',
        'C': '6-8 glasses',
        'D': '8+ glasses'
      }
    },
    {
      'category': 'Health Status',
      'question': 'How often do you eat vegetables and fruits?',
      'options': {
        'A': 'Rarely',
        'B': 'A few times a week',
        'C': 'Almost daily',
        'D': 'Multiple times daily'
      }
    },
    {
      'category': 'Health Status',
      'question': 'How well do you generally feel throughout the day?',
      'options': {
        'A': 'Often tired and low energy',
        'B': 'Sometimes energetic, sometimes tired',
        'C': 'Mostly energetic',
        'D': 'Consistently energetic throughout the day'
      }
    },

    // Gym Experience - 5 questions
    {
      'category': 'Gym Experience',
      'question': 'How long have you been training in a gym?',
      'options': {
        'A': 'Never been to a gym',
        'B': 'Less than 6 months',
        'C': '6 months to 2 years',
        'D': 'More than 2 years'
      }
    },
    {
      'category': 'Gym Experience',
      'question': 'Are you familiar with basic gym equipment?',
      'options': {
        'A': 'Not at all',
        'B': 'Somewhat familiar',
        'C': 'Familiar with most equipment',
        'D': 'Very experienced'
      }
    },
    {
      'category': 'Gym Experience',
      'question':
          'How comfortable are you with free weights (dumbbells, barbells)?',
      'options': {
        'A': 'Not comfortable at all',
        'B': 'Somewhat comfortable with light weights',
        'C': 'Comfortable with moderate weights',
        'D': 'Very comfortable with heavy weights'
      }
    },
    {
      'category': 'Gym Experience',
      'question': 'How often do you change your workout routine?',
      'options': {
        'A': 'I don\'t have a routine',
        'B': 'Rarely change it',
        'C': 'Every few months',
        'D': 'Regularly (every 4-6 weeks)'
      }
    },
    {
      'category': 'Gym Experience',
      'question': 'Can you perform basic compound movements correctly?',
      'options': {
        'A': 'I don\'t know what those are',
        'B': 'I know them but need form correction',
        'C': 'Yes, with good form',
        'D': 'Yes, with perfect form and advanced variations'
      }
    },
  ];

  Widget _buildProgressHeader() {
    double progress = (_currentPage + 1) / questions.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Fitness Assessment",
                style: TextStyle(
                  color: TColor.secondaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "${(_currentPage + 1)}/${questions.length}",
                style: TextStyle(
                  color: TColor.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: TColor.gray.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(TColor.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> questionData) {
    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: TColor.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TColor.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fitness_center, color: TColor.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      questionData['category'],
                      style: TextStyle(
                        color: TColor.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                questionData['question'],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: TColor.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 25),
              ...questionData['options'].entries.map((option) {
                bool isSelected =
                    _answers[questionData['question']] == option.key;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        // Unselect if already selected
                        _answers.remove(questionData['question']);
                      } else {
                        _answers[questionData['question']] = option.key;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? TColor.primary
                            : TColor.gray.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? TColor.primary.withOpacity(0.15)
                          : TColor.white,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? TColor.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? TColor.primary
                                  : TColor.gray.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(Icons.check, size: 16, color: TColor.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.value,
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected
                                  ? TColor.primary
                                  : TColor.secondaryText,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TColor.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            if (widget.isUpdate) {
              // If updating, just pop back to previous screen
              Navigator.of(context).pop();
            } else {
              // Original behavior for new users
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const Step1View(
                          username: '',
                        )),
                (route) => false,
              );
            }
          },
          icon: Image.asset(
            "assets/img/back.png",
            width: 25,
            height: 25,
          ),
        ),
        title: Text(
          widget.isUpdate ? "Update Assessment" : "Step 2 of 3",
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
            _buildProgressHeader(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Disable scrolling
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  return Center(
                    child: SingleChildScrollView(
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable scrolling
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: _buildQuestionCard(questions[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildNavigationButtons(),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    // Check if current question has an answer
    bool currentQuestionAnswered =
        _answers.containsKey(questions[_currentPage]['question']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColor.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Previous'),
                ),
              ),
            ),
          if (_currentPage < questions.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentQuestionAnswered
                        ? TColor.primary
                        : TColor.gray.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: currentQuestionAnswered
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: currentQuestionAnswered
                          ? TColor.white
                          : TColor.secondaryText.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
          if (_currentPage == questions.length - 1)
            Expanded(
              child: RoundButton(
                title: "Complete",
                onPressed: currentQuestionAnswered ? _navigateToStep3 : () {},
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToStep3() {
    // Calculate fitness level based on answers
    int totalScore = 0;
    int totalAnswered = 0;

    _answers.forEach((question, answer) {
      totalAnswered++;
      if (answer == 'A') totalScore += 1;
      if (answer == 'B') totalScore += 2;
      if (answer == 'C') totalScore += 3;
      if (answer == 'D') totalScore += 4;
    });

    // Calculate average score per question
    double avgScore = totalAnswered > 0 ? totalScore / totalAnswered : 0;

    // Determine fitness level
    int fitnessLevel = 0;
    if (avgScore >= 3.2) {
      // 80% of max score (4)
      fitnessLevel = 2; // Expert
    } else if (avgScore >= 2.0) {
      // 50% of max score
      fitnessLevel = 1; // Intermediate
    }
    // else remains 0 for Beginner

    if (widget.isUpdate) {
      // If this is an update, update Firestore and show completion dialog
      _updateUserFitnessLevel(fitnessLevel);
    } else {
      // For new users, make sure we navigate to Step3View correctly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Step3View(
            username: widget.username,
            initialFitnessLevel: fitnessLevel,
          ),
        ),
      );
    }
  }

  // Modified method to update fitness level in Firestore with refresh notification
  void _updateUserFitnessLevel(int fitnessLevel) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Updating your fitness level...')
                ],
              ),
            ),
          );
        },
      );

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(widget.username)
          .update({'fitnessLevel': fitnessLevel});

      // Add a special update flag to notify other components that fitness level changed
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(widget.username)
          .update({
        'fitnessLevelUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Hide loading dialog and show success dialog
      Navigator.pop(context);

      // Show success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Assessment Updated',
              style: TextStyle(
                color: TColor.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Quicksand',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: TColor.primary,
                  size: 50,
                ),
                const SizedBox(height: 15),
                Text(
                  'Your fitness level has been successfully updated to ${_getFitnessLevelName(fitnessLevel)}.',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Quicksand',
                    color: TColor.secondaryText,
                  ),
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
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Quicksand',
                  ),
                ),
                onPressed: () {
                  // Close all dialogs and go back to settings
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          );
        },
      );
    } catch (e) {
      // Hide loading dialog and show error
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating fitness level: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to get the fitness level name
  String _getFitnessLevelName(int level) {
    switch (level) {
      case 0:
        return 'Beginner';
      case 1:
        return 'Intermediate';
      case 2:
        return 'Expert';
      default:
        return 'Unknown';
    }
  }
}
