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

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController answerController = TextEditingController();

  String selectedQuestion = "color_question";

  final List<String> questions = [
    "color_question",
    "pet_question",
    "city_question",
  ];

  Future<void> registerUser() async {

    final prefs = await SharedPreferences.getInstance();

    String username = usernameController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();
    String answer = answerController.text.trim();

    if (!mounted) return;

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty || answer.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("fill_fields"))),
      );
      return;
    }

    if (password != confirmPassword) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("password_mismatch"))),
      );
      return;
    }

    await prefs.setString("email", username);
    await prefs.setString("password", password);
    await prefs.setString("securityQuestion", selectedQuestion);
    await prefs.setString("securityAnswer", answer);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageHelper.t("register"))),
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
                hint: LanguageHelper.t("email"),
                icon: Icons.person_outline,
                controller: usernameController,
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

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: selectedQuestion,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.help_outline),
                  border: OutlineInputBorder(),
                ),
                items: questions.map((q) {
                  return DropdownMenuItem(
                    value: q,
                    child: Text(LanguageHelper.t(q)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedQuestion = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              InputField(
                hint: LanguageHelper.t("enter_answer"),
                icon: Icons.question_answer_outlined,
                controller: answerController,
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