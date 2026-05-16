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

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10;
  }

  Future<void> loginUser() async {
    final prefs = await SharedPreferences.getInstance();

    String savedPhone = prefs.getString("mobile") ?? "";
    String savedPassword = prefs.getString("password") ?? "";

    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("enter_credentials"))),
      );

      return;
    }

    if (!_isValidPhone(phone)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("valid_phone"))),
      );

      return;
    }

    if (savedPhone.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("no_account"))),
      );

      return;
    }

    if (phone == savedPhone && password == savedPassword) {

      await prefs.setBool("loggedIn", true);
      if (!mounted) return;

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
              controller: phoneController,
              decoration: InputDecoration(
                labelText: LanguageHelper.t("phone_number"),
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
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
