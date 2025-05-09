import 'package:fitness_app/view/home/home_view.dart';
import 'package:fitness_app/view/login/Sign_In.dart';
import 'package:fitness_app/view/login/step1_view.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../common/color_extension.dart';

class LogInScreen extends StatefulWidget {
  @override
  _LogInScreenState createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Constants for character limits
  static const int kMaxUsernameLength = 20;
  static const int kMaxPasswordLength = 32;

  // Security settings
  static const int kMaxLoginAttempts = 5;
  static const int kLockoutDurationMinutes = 15;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _buttonPulseAnimation;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _usernameError;
  String? _passwordError;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

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

    _buttonPulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Add listeners for real-time validation
    _usernameController.addListener(_validateUsername);
    _passwordController.addListener(_validatePassword);

    // Check for account lockout
    _checkAccountLockout();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();

    // Remove listeners
    _usernameController.removeListener(_validateUsername);
    _passwordController.removeListener(_validatePassword);

    super.dispose();
  }

  void _validateUsername() {
    if (_usernameController.text.length > kMaxUsernameLength) {
      setState(() {
        _usernameController.text =
            _usernameController.text.substring(0, kMaxUsernameLength);
        _usernameController.selection = TextSelection.fromPosition(
            TextPosition(offset: _usernameController.text.length));
      });
    } else {
      setState(() {
        _usernameError = null;
      });
    }
  }

  void _validatePassword() {
    if (_passwordController.text.length > kMaxPasswordLength) {
      setState(() {
        _passwordController.text =
            _passwordController.text.substring(0, kMaxPasswordLength);
        _passwordController.selection = TextSelection.fromPosition(
            TextPosition(offset: _passwordController.text.length));
      });
    } else {
      setState(() {
        _passwordError = null;
      });
    }
  }

  // Secure password verification that handles salted hashes
  bool _verifyPassword(String storedHash, String inputPassword) {
    if (storedHash.contains(':')) {
      // New format with salt
      final parts = storedHash.split(':');
      final hash = parts[0];
      final salt = parts[1];

      // Hash the input with the same salt
      final bytes = utf8.encode(inputPassword + salt);
      final digest = sha256.convert(bytes);

      return hash == digest.toString();
    } else {
      // Legacy format (plain SHA-256)
      final bytes = utf8.encode(inputPassword);
      final digest = sha256.convert(bytes);
      return storedHash == digest.toString();
    }
  }

  // Check if account is locked due to too many failed attempts
  Future<bool> _checkAccountLockout() async {
    if (_usernameController.text.isEmpty) return false;

    try {
      final lockoutDoc = await _firestore
          .collection('login_security')
          .doc(_usernameController.text)
          .get();

      if (lockoutDoc.exists) {
        final data = lockoutDoc.data();
        if (data != null &&
            data['failedAttempts'] != null &&
            data['failedAttempts'] >= kMaxLoginAttempts &&
            data['lockedUntil'] != null) {
          final lockedUntil = (data['lockedUntil'] as Timestamp).toDate();
          if (DateTime.now().isBefore(lockedUntil)) {
            final remainingMinutes =
                lockedUntil.difference(DateTime.now()).inMinutes + 1;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Account locked. Try again in $remainingMinutes minute(s).'),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 5),
              ),
            );
            return true;
          } else {
            // Lockout period expired, reset the counter
            await _firestore
                .collection('login_security')
                .doc(_usernameController.text)
                .set({'failedAttempts': 0, 'lockedUntil': null});
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking account lockout: $e');
      return false;
    }
  }

  // Track failed login attempts and implement account lockout if needed
  Future<void> _trackFailedAttempt() async {
    if (_usernameController.text.isEmpty) return;

    try {
      final lockoutDoc = await _firestore
          .collection('login_security')
          .doc(_usernameController.text)
          .get();

      int failedAttempts = 1;

      if (lockoutDoc.exists) {
        final data = lockoutDoc.data();
        if (data != null && data['failedAttempts'] != null) {
          failedAttempts = (data['failedAttempts'] as int) + 1;
        }
      }

      await _firestore
          .collection('login_security')
          .doc(_usernameController.text)
          .set({
        'failedAttempts': failedAttempts,
        'lastAttempt': FieldValue.serverTimestamp(),
        'lockedUntil': failedAttempts >= kMaxLoginAttempts
            ? Timestamp.fromDate(
                DateTime.now().add(Duration(minutes: kLockoutDurationMinutes)))
            : null
      });

      // Show warning if approaching lockout
      if (failedAttempts >= 3 && failedAttempts < kMaxLoginAttempts) {
        int attemptsLeft = kMaxLoginAttempts - failedAttempts;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Warning: $attemptsLeft login attempts remaining before account lockout.'),
            backgroundColor: Colors.amber.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error tracking failed attempt: $e');
    }
  }

  // Reset failed login attempts on successful login
  Future<void> _resetFailedAttempts() async {
    if (_usernameController.text.isEmpty) return;

    try {
      await _firestore
          .collection('login_security')
          .doc(_usernameController.text)
          .set({
        'failedAttempts': 0,
        'lockedUntil': null,
        'lastSuccessfulLogin': FieldValue.serverTimestamp()
      });
    } catch (e) {
      print('Error resetting failed attempts: $e');
    }
  }

  Future<void> _loginUser() async {
    // Check form validity
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check for account lockout
    bool isLocked = await _checkAccountLockout();
    if (isLocked) return;

    setState(() => _isLoading = true);

    try {
      // Check user credentials directly in Firestore
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: _usernameController.text)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        await _trackFailedAttempt();
        throw 'User not found';
      }

      final userDoc = userQuery.docs.first;
      String storedPassword = userDoc['password'];

      if (!_verifyPassword(storedPassword, _passwordController.text)) {
        await _trackFailedAttempt();
        throw 'Invalid password';
      }

      // Reset failed attempts counter on successful login
      await _resetFailedAttempts();

      // Save login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _usernameController.text);

      // Track login date for security purposes
      final today =
          DateTime.now().toString().split(' ')[0]; // Just the date part
      await prefs.setString('lastLoginDate', today);

      // Check user profile
      final userProfileDoc = await _firestore
          .collection('user_profiles')
          .doc(_usernameController.text)
          .get();

      if (userProfileDoc.exists) {
        final profileData = userProfileDoc.data();
        if (profileData != null &&
            profileData['birthDate'] != null &&
            profileData['weight'] != null &&
            profileData['height'] != null &&
            profileData['isMale'] != null &&
            profileData['fitnessLevel'] != null) {
          // Profile is complete, redirect to home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeView(
                username: _usernameController.text,
              ),
            ),
            (route) => false,
          );
          return;
        }
      }

      // If profile is incomplete, navigate to Step1View
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => Step1View(
            username: _usernameController.text,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      print('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                  child: Text('Login failed: Invalid username or password')),
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
    // Check if keyboard is visible
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: TColor.primary,
      // Using ResizeToAvoidBottomInset to allow resizing when keyboard appears
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background image
          Image.asset(
            'assets/img/on_board_bg.png',
            width: media.width,
            height: media.height,
            fit: BoxFit.cover,
          ),

          // Make the content scrollable when keyboard appears
          SafeArea(
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: media.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        // Logo with animation - restore to full size, hide when keyboard visible
                        if (!isKeyboardVisible)
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Container(
                                height: media.height * 0.3,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: media.height * 0.05),
                                child: Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: Transform.rotate(
                                    angle: _rotateAnimation.value,
                                    child: Image.asset(
                                      'assets/img/grit_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // Fixed spacing when keyboard is not visible, reduced when visible
                        isKeyboardVisible
                            ? SizedBox(height: 300)
                            : SizedBox(height: media.height * 0.27),

                        // Form container - in original position when keyboard not visible
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
                                // Enhanced welcome text
                                Text(
                                  "Welcome!",
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 22, // Reduced from 28
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "Ready for your workout?",
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 14, // Reduced from 16
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                        color: Colors.black.withOpacity(0.2),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 25),

                                // Username field
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.9),
                                    labelText: 'Username',
                                    errorText: _usernameError,
                                    errorStyle: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    labelStyle: TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Quicksand',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.black.withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 2.5,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: Colors.black,
                                      size: 24,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  validator: (value) {
                                    if (value != null &&
                                        value.length > kMaxUsernameLength) {
                                      return 'Username cannot exceed $kMaxUsernameLength characters';
                                    }
                                    return null;
                                  },
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(
                                        kMaxUsernameLength),
                                  ],
                                ),
                                SizedBox(height: 15),

                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.9),
                                    labelText: 'Password',
                                    errorText: _passwordError,
                                    errorStyle: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    labelStyle: TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Quicksand',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.black.withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 2.5,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: Colors.black,
                                      size: 24,
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
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  obscureText: _obscurePassword,
                                  validator: (value) {
                                    if (value != null &&
                                        value.length > kMaxPasswordLength) {
                                      return 'Password cannot exceed $kMaxPasswordLength characters';
                                    }
                                    return null;
                                  },
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(
                                        kMaxPasswordLength),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Login button - updating to white color
                        SizedBox(height: 25),
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _buttonPulseAnimation.value,
                              child: Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white, // Changed to white
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _loginUser,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    disabledBackgroundColor:
                                        Colors.white.withOpacity(0.7),
                                    disabledForegroundColor: Colors.grey,
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
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(TColor.primary),
                                                strokeWidth: 3,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              "Logging In...",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Quicksand',
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          "LOG IN",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Quicksand',
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Bottom row with signup link - only show when keyboard is not visible
                        if (!isKeyboardVisible) ...[
                          Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Need an Account?",
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
                                      builder: (context) => SignInScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.all(10),
                                  splashFactory: InkRipple.splashFactory,
                                ),
                                child: Text(
                                  "Sign Up",
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
                          SizedBox(height: 10),
                        ] else
                          SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
