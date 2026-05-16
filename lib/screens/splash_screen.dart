import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../utils/language_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool("loggedIn") ?? false;

    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => isLoggedIn ? const HomeScreen() : const LoginScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(

        decoration: const BoxDecoration(
          color: Color(0xFFFFE4E6),
        ),

        child: Stack(
          children: [

            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  "assets/images/ambulance.jpeg",
                  fit: BoxFit.cover,
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Image.asset(
                    "assets/images/app_logo.jpeg",
                    height: 110,
                  ),

                  const SizedBox(height: 30),

                  Lottie.asset(
                    "assets/animations/hourglass.json",
                    height: 100,
                  ),

                  const SizedBox(height: 30),

                  Text(
                    LanguageHelper.t("tagline"),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
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
}
