import 'package:firebase_core/firebase_core.dart';
import 'package:fitness_app/firebase_options.dart';
import 'package:fitness_app/models/push_up_model.dart';
import 'package:fitness_app/view/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PushUpCounter(),
      child: MaterialApp(
        title: 'Grit',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: "Quicksand",
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: false,
        ),
        home: const SplashView(), // Changed from OnBoardingView to SplashView
      ),
    );
  }
}
