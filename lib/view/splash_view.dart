import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/view/home/home_view.dart';
import 'package:fitness_app/view/login/on_boarding_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({Key? key}) : super(key: key);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? username = prefs.getString('username');
    final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      // First time opening app
      await prefs.setBool('isFirstTime', false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnBoardingView()),
      );
    } else if (username != null) {
      // User is logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeView(username: username)),
      );
    } else {
      // User is not logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnBoardingView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
