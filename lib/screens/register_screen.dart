import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';
import '../utils/language_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10;
  }

  Future<void> registerUser() async {
    final prefs = await SharedPreferences.getInstance();

    String phone = phoneController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("fill_fields"))),
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

    if (email.isNotEmpty && !RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("valid_email_optional"))),
      );
      return;
    }

    if (password != confirmPassword) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("password_mismatch"))),
      );
      return;
    }

    await prefs.setString("mobile", phone);
    await prefs.setString("email", email);
    await prefs.setString("password", password);
    await prefs.setBool("loggedIn", false);
    await prefs.setBool("emailVerified", false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageHelper.t("account_created"))),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4EC),

      appBar: AppBar(
        title: Text(LanguageHelper.t("register")),
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              const SizedBox(height: 30),

              Text(
                LanguageHelper.t("create_account"),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24,fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                LanguageHelper.t("start_monitoring"),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14,color: Colors.black54),
              ),

              const SizedBox(height: 35),

              InputField(
                hint: LanguageHelper.t("phone_number"),
                icon: Icons.phone_android,
                controller: phoneController,
              ),

              const SizedBox(height: 20),

              InputField(
                hint: LanguageHelper.t("email_optional"),
                icon: Icons.email_outlined,
                controller: emailController,
              ),

              const SizedBox(height: 20),

              InputField(
                hint: LanguageHelper.t("password"),
                icon: Icons.lock_outline,
                controller: passwordController,
                obscureText: true,
              ),

              const SizedBox(height: 20),

              InputField(
                hint: LanguageHelper.t("confirm_password"),
                icon: Icons.lock_outline,
                controller: confirmPasswordController,
                obscureText: true,
              ),

              const SizedBox(height: 30),

              PrimaryButton(
                text: LanguageHelper.t("register"),
                onPressed: registerUser,
              ),

              const SizedBox(height: 25),

            ],
          ),
        ),
      ),
    );
  }
}
