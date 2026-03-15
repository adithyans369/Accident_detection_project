import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../utils/language_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> loginUser() async {

    final prefs = await SharedPreferences.getInstance();

    String savedEmail = prefs.getString("email") ?? "";
    String savedPassword = prefs.getString("password") ?? "";

    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    bool validEmail = RegExp(r'\S+@\S+\.\S+').hasMatch(email);

    if (!mounted) return;

    if (email.isEmpty || password.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("enter_credentials"))),
      );

      return;
    }

    if (!validEmail) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("valid_email"))),
      );

      return;
    }

    if (savedEmail.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("no_account"))),
      );

      return;
    }

    if (email == savedEmail && password == savedPassword) {

      await prefs.setBool("loggedIn", true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("invalid_login"))),
      );

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFFFE4EC),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(
              Icons.health_and_safety,
              size: 90,
              color: Colors.red,
            ),

            const SizedBox(height: 20),

            const Text(
              "A4 Safe Pulse",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: LanguageHelper.t("email"),
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: LanguageHelper.t("password"),
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: loginUser,
              child: Text(LanguageHelper.t("login")),
            ),

            const SizedBox(height: 15),

            TextButton(

              onPressed: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                );

              },

              child: Text(LanguageHelper.t("forgot_password")),
            ),

            TextButton(

              onPressed: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );

              },

              child: Text(LanguageHelper.t("signup")),
            ),

          ],
        ),
      ),
    );
  }
}