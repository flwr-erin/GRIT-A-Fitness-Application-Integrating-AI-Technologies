import 'package:fitness_app/view/login/Log_In.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness_app/model/user_model.dart';
import '../../common/color_extension.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math'; // For generating salt

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Constants for character limits
  static const int kMaxNameLength = 30;
  static const int kMaxUsernameLength = 20;
  static const int kMinUsernameLength = 4;
  static const int kMinPasswordLength = 8;
  static const int kMaxPasswordLength = 32;

  // Password strength indicators
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  double _passwordStrength = 0.0;

  // Form completion tracking for gamification
  bool _firstNameCompleted = false;
  bool _lastNameCompleted = false;
  bool _usernameCompleted = false;
  bool _passwordCompleted = false;
  bool _confirmPasswordCompleted = false;
  double _formCompletionPercentage = 0.0;

  // New animation controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _buttonScaleAnimation;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();

  // Add error state variables for first and last name
  String? _firstNameError;
  String? _lastNameError;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Add listeners to first name and last name controllers
    _firstNameController.addListener(_validateFirstName);
    _lastNameController.addListener(_validateLastName);
    _usernameController.addListener(_validateUsername);
    _confirmPasswordController.addListener(_validateConfirmPassword);

    // Add listener for password strength
    _passwordController.addListener(_checkPasswordStrength);

    // Calculate initial form completion percentage
    _calculateFormCompletion();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    // Remove listeners before disposing controllers
    _firstNameController.removeListener(_validateFirstName);
    _lastNameController.removeListener(_validateLastName);
    _usernameController.removeListener(_validateUsername);
    _passwordController.removeListener(_checkPasswordStrength);
    _confirmPasswordController.removeListener(_validateConfirmPassword);

    super.dispose();
  }

  void _calculateFormCompletion() {
    int completedFields = 0;
    if (_firstNameCompleted) completedFields++;
    if (_lastNameCompleted) completedFields++;
    if (_usernameCompleted) completedFields++;
    if (_passwordCompleted) completedFields++;
    if (_confirmPasswordCompleted) completedFields++;

    setState(() {
      _formCompletionPercentage = completedFields / 5.0;
    });
  }

  // Validate username
  void _validateUsername() {
    final username = _usernameController.text;
    setState(() {
      _usernameCompleted = username.length >= kMinUsernameLength &&
          username.length <= kMaxUsernameLength;
      _calculateFormCompletion();
    });
  }

  // Validate confirm password
  void _validateConfirmPassword() {
    setState(() {
      _confirmPasswordCompleted =
          _confirmPasswordController.text == _passwordController.text &&
              _confirmPasswordController.text.isNotEmpty;
      _calculateFormCompletion();
    });
  }

  // Check password strength and update indicators
  void _checkPasswordStrength() {
    final password = _passwordController.text;

    setState(() {
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      // Calculate strength score (0.0 to 1.0)
      double strengthScore = 0.0;

      if (password.isEmpty) {
        strengthScore = 0.0;
      } else {
        // Base strength from length
        if (password.length >= kMinPasswordLength) strengthScore += 0.1;
        if (password.length >= 10) strengthScore += 0.1;
        if (password.length >= 12) strengthScore += 0.1;

        // Add strength for character variety
        if (_hasUppercase) strengthScore += 0.2;
        if (_hasLowercase) strengthScore += 0.2;
        if (_hasNumber) strengthScore += 0.2;
        if (_hasSpecialChar) strengthScore += 0.2;

        // Cap the maximum value at 1.0
        strengthScore = min(strengthScore, 1.0);
      }

      _passwordStrength = strengthScore;
      _passwordCompleted =
          _passwordStrength >= 0.4 && password.length >= kMinPasswordLength;
      _calculateFormCompletion();
    });
  }

  // Validation method for first name
  void _validateFirstName() {
    final value = _firstNameController.text;
    if (value.isEmpty) {
      setState(() {
        _firstNameError = null;
        _firstNameCompleted = false;
      });
    } else if (RegExp(r'[0-9]').hasMatch(value)) {
      setState(() {
        _firstNameError = 'Numbers are not allowed';
        _firstNameCompleted = false;
      });
    } else {
      setState(() {
        _firstNameError = null;
        _firstNameCompleted = value.isNotEmpty;
      });
    }
    _calculateFormCompletion();
  }

  // Validation method for last name
  void _validateLastName() {
    final value = _lastNameController.text;
    if (value.isEmpty) {
      setState(() {
        _lastNameError = null;
        _lastNameCompleted = false;
      });
    } else if (RegExp(r'[0-9]').hasMatch(value)) {
      setState(() {
        _lastNameError = 'Numbers are not allowed';
        _lastNameCompleted = false;
      });
    } else {
      setState(() {
        _lastNameError = null;
        _lastNameCompleted = value.isNotEmpty;
      });
    }
    _calculateFormCompletion();
  }

  String _hashPassword(String password) {
    // Generate a random salt
    final String salt = DateTime.now().millisecondsSinceEpoch.toString();

    // Combine password and salt, then hash
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);

    // Store the hash and salt together
    return '${digest.toString()}:$salt';
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for password strength
    if (_passwordStrength < 0.4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.shield, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Level up your security! Add uppercase letters, numbers, and special characters to your password.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if username exists
      final QuerySnapshot existingUsers = await _firestore
          .collection('users')
          .where('username', isEqualTo: _usernameController.text)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        throw 'Username already exists';
      }

      // Create new user document with auto-generated ID
      final userDoc = _firestore.collection('users').doc();

      final userModel = UserModel(
        uid: userDoc.id,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        username: _usernameController.text,
        password: _hashPassword(_passwordController.text),
      );

      await userDoc.set(userModel.toJson());
      print('User created successfully with ID: ${userDoc.id}');

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LogInScreen(),
          settings: RouteSettings(name: 'LoginScreen'),
        ),
        (route) => false,
      );

      // Removed the achievement notification
    } catch (e) {
      print('Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Registration failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TColor.primary,
      body: Stack(
        children: [
          // Background image
          Image.asset(
            'assets/img/on_board_bg.png',
            width: media.width,
            height: media.height,
            fit: BoxFit.cover,
          ),

          // Animated logo in white part
          Positioned(
            top: media.height * 0.08,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: Container(
                      height: media.height * 0.25,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Image.asset(
                        'assets/img/grit_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Main container
          SafeArea(
            child: Column(
              children: [
                // Space for logo
                SizedBox(height: media.height * 0.40),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        children: [
                          // Gamified progress indicator
                          Container(
                            margin: EdgeInsets.only(bottom: 15),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Profile Creation Progress",
                                      style: TextStyle(
                                        fontFamily: 'Quicksand',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      "${(_formCompletionPercentage * 100).toInt()}%",
                                      style: TextStyle(
                                        fontFamily: 'Quicksand',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: _formCompletionPercentage,
                                    backgroundColor:
                                        Colors.grey.withOpacity(0.3),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _formCompletionPercentage == 1
                                            ? Colors.green
                                            : TColor.primary),
                                    minHeight: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Form container
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.black,
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  spreadRadius: 1,
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Enhanced title text with better visibility
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Create an Account",
                                            style: TextStyle(
                                              fontFamily: 'Quicksand',
                                              fontSize: 20, // Reduced from 24
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              shadows: [
                                                Shadow(
                                                  offset: Offset(1, 1),
                                                  blurRadius: 3,
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            "Join GRIT today",
                                            style: TextStyle(
                                              fontFamily: 'Quicksand',
                                              fontSize: 14, // Reduced from 16
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                              shadows: [
                                                Shadow(
                                                  offset: Offset(1, 1),
                                                  blurRadius: 2,
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.fitness_center,
                                          color: Colors.black,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 25),

                                  // First and Last Name Row - Updated with visual error indicators
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            TextFormField(
                                              controller: _firstNameController,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(
                                                        RegExp(r'[a-zA-Z ]')),
                                                LengthLimitingTextInputFormatter(
                                                    kMaxNameLength),
                                              ],
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Required';
                                                }
                                                if (!RegExp(r'^[a-zA-Z ]+$')
                                                    .hasMatch(value.trim())) {
                                                  return 'Letters only';
                                                }
                                                return null;
                                              },
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withOpacity(0.9),
                                                labelText: 'First Name',
                                                errorText: _firstNameError,
                                                errorStyle: TextStyle(
                                                  color: Colors.red.shade800,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                labelStyle: TextStyle(
                                                    color: Colors.black,
                                                    fontFamily: 'Quicksand',
                                                    fontWeight:
                                                        FontWeight.w600),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: BorderSide(
                                                      color: Colors.black,
                                                      width: 1.5),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: BorderSide(
                                                      color: Colors.black
                                                          .withOpacity(0.7),
                                                      width: 1.5),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: BorderSide(
                                                    color: _firstNameError !=
                                                            null
                                                        ? Colors.red.shade800
                                                        : Colors.black,
                                                    width: 2.5,
                                                  ),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 15,
                                                        vertical: 18),
                                                prefixIcon: Icon(
                                                  Icons.person_outline,
                                                  color: _firstNameError != null
                                                      ? Colors.red.shade800
                                                      : Colors.black,
                                                  size: 24,
                                                ),
                                                isDense: true,
                                              ),
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontFamily: 'Quicksand',
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            if (_firstNameCompleted)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            TextFormField(
                                              controller: _lastNameController,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(
                                                        RegExp(r'[a-zA-Z ]')),
                                                LengthLimitingTextInputFormatter(
                                                    kMaxNameLength),
                                              ],
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Required';
                                                }
                                                if (!RegExp(r'^[a-zA-Z ]+$')
                                                    .hasMatch(value.trim())) {
                                                  return 'Letters only';
                                                }
                                                return null;
                                              },
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(
                                                    0.9), // Increased opacity for better visibility
                                                labelText: 'Last Name',
                                                errorText: _lastNameError,
                                                errorStyle: TextStyle(
                                                  color: Colors.red.shade800,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                labelStyle: TextStyle(
                                                    color: Colors
                                                        .black, // Changed from TColor.primary to black
                                                    fontFamily: 'Quicksand',
                                                    fontWeight:
                                                        FontWeight.w600),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: BorderSide(
                                                      color: Colors.black,
                                                      width:
                                                          1), // Changed border color to black
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: BorderSide(
                                                      color: Colors.black,
                                                      width:
                                                          1), // Changed border color to black
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  borderSide: BorderSide(
                                                    color: _lastNameError !=
                                                            null
                                                        ? Colors.red.shade800
                                                        : Colors.black,
                                                    width:
                                                        2.5, // Kept the thicker border when focused
                                                  ),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 15,
                                                        vertical:
                                                            18), // Slightly taller input box
                                                prefixIcon: Icon(
                                                  Icons.person_outline,
                                                  color: _lastNameError != null
                                                      ? Colors.red.shade800
                                                      : Colors.black,
                                                  size:
                                                      24, // Slightly larger icon
                                                ),
                                                isDense: true,
                                              ),
                                              style: TextStyle(
                                                  color: Colors
                                                      .black, // Changed text color to black for better visibility
                                                  fontFamily: 'Quicksand',
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            if (_lastNameCompleted)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 15),

                                  // Username field
                                  Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      TextFormField(
                                        controller: _usernameController,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(
                                              kMaxUsernameLength),
                                        ],
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Username is required';
                                          }
                                          if (value.length <
                                              kMinUsernameLength) {
                                            return 'Username must be at least $kMinUsernameLength characters';
                                          }
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(
                                              0.9), // Increased opacity for better visibility
                                          labelText: 'Username',
                                          labelStyle: TextStyle(
                                              color: Colors
                                                  .black, // Changed from TColor.primary to black
                                              fontFamily: 'Quicksand',
                                              fontWeight: FontWeight.w600),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: BorderSide(
                                                color: Colors.black,
                                                width:
                                                    1), // Changed border color to black
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: BorderSide(
                                                color: Colors.black,
                                                width:
                                                    1), // Changed border color to black
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: BorderSide(
                                              color: Colors
                                                  .black, // Changed focus border color to black
                                              width:
                                                  2.5, // Kept the thicker border when focused
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 15,
                                              vertical:
                                                  18), // Taller input box for better visibility
                                          prefixIcon: Icon(
                                            Icons.alternate_email,
                                            color: Colors.black,
                                            size: 24, // Slightly larger icon
                                          ),
                                          isDense: true,
                                        ),
                                        style: TextStyle(
                                            color: Colors
                                                .black, // Changed text color to black for better visibility
                                            fontFamily: 'Quicksand',
                                            fontWeight: FontWeight.w500),
                                      ),
                                      if (_usernameCompleted)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 15),

                                  // Password field with strength meter
                                  Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextFormField(
                                            controller: _passwordController,
                                            inputFormatters: [
                                              LengthLimitingTextInputFormatter(
                                                  kMaxPasswordLength),
                                            ],
                                            obscureText: _obscurePassword,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Password is required';
                                              }
                                              if (value.length <
                                                  kMinPasswordLength) {
                                                return 'Password must be at least $kMinPasswordLength characters';
                                              }
                                              if (!_hasUppercase) {
                                                return 'Password must contain at least one uppercase letter';
                                              }
                                              if (!_hasNumber) {
                                                return 'Password must contain at least one number';
                                              }
                                              if (!_hasSpecialChar) {
                                                return 'Password must contain at least one special character';
                                              }
                                              return null;
                                            },
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(
                                                  0.9), // Increased opacity for better visibility
                                              labelText: 'Password',
                                              labelStyle: TextStyle(
                                                  color: Colors
                                                      .black, // Changed from TColor.primary to black
                                                  fontFamily: 'Quicksand',
                                                  fontWeight: FontWeight.w600),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                borderSide: BorderSide(
                                                    color: Colors.black,
                                                    width:
                                                        1), // Changed border color to black
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                borderSide: BorderSide(
                                                    color: Colors.black,
                                                    width:
                                                        1), // Changed border color to black
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                borderSide: BorderSide(
                                                  color: Colors
                                                      .black, // Changed focus border color to black
                                                  width:
                                                      2.5, // Kept the thicker border when focused
                                                ),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 15,
                                                      vertical:
                                                          18), // Taller input box
                                              prefixIcon: Icon(
                                                Icons.lock_outline,
                                                color: Colors.black,
                                                size:
                                                    24, // Slightly larger icon
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons.visibility_off
                                                      : Icons.visibility,
                                                  color: Colors.black,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _obscurePassword =
                                                        !_obscurePassword;
                                                  });
                                                },
                                              ),
                                              isDense: true,
                                            ),
                                            style: TextStyle(
                                                color: Colors
                                                    .black, // Changed text color to black for better visibility
                                                fontFamily: 'Quicksand',
                                                fontWeight: FontWeight.w500),
                                          ),
                                          SizedBox(height: 8),

                                          // Password strength meter - gamified
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    "Password Strength: ",
                                                    style: TextStyle(
                                                      fontFamily: 'Quicksand',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  Text(
                                                    _passwordStrength <= 0.3
                                                        ? "Weak"
                                                        : _passwordStrength <=
                                                                0.6
                                                            ? "Medium"
                                                            : "Strong",
                                                    style: TextStyle(
                                                      fontFamily: 'Quicksand',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: _passwordStrength <=
                                                              0.3
                                                          ? Colors.red
                                                          : _passwordStrength <=
                                                                  0.6
                                                              ? Colors.orange
                                                              : Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 5),
                                              Container(
                                                width: double.infinity,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  color: Colors.grey
                                                      .withOpacity(0.3),
                                                ),
                                                child: FractionallySizedBox(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  widthFactor:
                                                      _passwordStrength,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                      color: _passwordStrength <=
                                                              0.3
                                                          ? Colors.red
                                                          : _passwordStrength <=
                                                                  0.6
                                                              ? Colors.orange
                                                              : Colors.green,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    _buildRequirementChip(
                                                        "8+ chars",
                                                        _passwordController
                                                                .text.length >=
                                                            kMinPasswordLength),
                                                    SizedBox(width: 4),
                                                    _buildRequirementChip(
                                                        "ABC", _hasUppercase),
                                                    SizedBox(width: 4),
                                                    _buildRequirementChip(
                                                        "abc", _hasLowercase),
                                                    SizedBox(width: 4),
                                                    _buildRequirementChip(
                                                        "123", _hasNumber),
                                                    SizedBox(width: 4),
                                                    _buildRequirementChip(
                                                        "!@#", _hasSpecialChar),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (_passwordCompleted)
                                        Positioned(
                                          top: 8,
                                          right:
                                              40, // Adjust position to avoid overlapping with visibility icon
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 15),

                                  // Confirm Password field
                                  Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(
                                              kMaxPasswordLength),
                                        ],
                                        obscureText: _obscureConfirmPassword,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please confirm your password';
                                          }
                                          if (value !=
                                              _passwordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(
                                              0.9), // Increased opacity for better visibility
                                          labelText: 'Confirm Password',
                                          labelStyle: TextStyle(
                                              color: Colors
                                                  .black, // Changed from TColor.primary to black
                                              fontFamily: 'Quicksand',
                                              fontWeight: FontWeight.w600),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: BorderSide(
                                                color: Colors.black,
                                                width:
                                                    1), // Changed border color to black
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: BorderSide(
                                                color: Colors.black,
                                                width:
                                                    1), // Changed border color to black
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            borderSide: BorderSide(
                                              color: Colors
                                                  .black, // Changed focus border color to black
                                              width:
                                                  2.5, // Kept the thicker border when focused
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 15,
                                              vertical: 18), // Taller input box
                                          prefixIcon: Icon(
                                            Icons.lock_outline,
                                            color: Colors.black,
                                            size: 24, // Slightly larger icon
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: Colors.black,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                          ),
                                          isDense: true,
                                        ),
                                        style: TextStyle(
                                            color: Colors
                                                .black, // Changed text color to black for better visibility
                                            fontFamily: 'Quicksand',
                                            fontWeight: FontWeight.w500),
                                      ),
                                      if (_confirmPasswordCompleted)
                                        Positioned(
                                          top: 8,
                                          right:
                                              40, // Adjust position to avoid overlapping with visibility icon
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Create account button
                          SizedBox(height: 25),
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _formCompletionPercentage == 1.0
                                    ? _buttonScaleAnimation.value
                                    : 1.0,
                                child: Container(
                                  width: double.infinity,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white, // Changed to white
                                    boxShadow: [
                                      BoxShadow(
                                        color: _formCompletionPercentage == 1.0
                                            ? Colors.black.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.2),
                                        spreadRadius: 2,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _registerUser,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: TColor.primary,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          TColor.primary),
                                                  strokeWidth: 3,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                "Creating Account...",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Quicksand',
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.fitness_center,
                                                  size: 22,
                                                  color: Colors.black),
                                              SizedBox(width: 10),
                                              Text(
                                                "BEGIN YOUR JOURNEY",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Quicksand',
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Login link
                          SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Quicksand',
                                  fontSize: 16,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LogInScreen(),
                                      settings:
                                          RouteSettings(name: 'LoginScreen'),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  splashFactory: InkRipple.splashFactory,
                                ),
                                child: Text(
                                  "Log In",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build requirement chips - compact version
  Widget _buildRequirementChip(String label, bool isMet) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isMet
            ? Colors.green.withOpacity(0.7)
            : Colors.grey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check : Icons.close,
            color: Colors.white,
            size: 8,
          ),
          SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
