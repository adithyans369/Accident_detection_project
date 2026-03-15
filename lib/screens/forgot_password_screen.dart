import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {

  final emailController = TextEditingController();
  final answerController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String securityQuestion = "";
  bool questionLoaded = false;
  bool allowReset = false;

  Future<void> loadQuestion() async {

    final prefs = await SharedPreferences.getInstance();

    String savedEmail = prefs.getString("email") ?? "";
    String savedQuestion = prefs.getString("securityQuestion") ?? "";

    if (emailController.text.trim() == savedEmail) {

      setState(() {
        securityQuestion = savedQuestion;
        questionLoaded = true;
      });

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("email_not_found"))),
      );
    }
  }

  Future<void> verifyAnswer() async {

    final prefs = await SharedPreferences.getInstance();

    String savedAnswer = prefs.getString("securityAnswer") ?? "";

    if (answerController.text.trim() == savedAnswer) {

      setState(() {
        allowReset = true;
      });

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("incorrect_answer"))),
      );
    }
  }

  Future<void> resetPassword() async {

    final prefs = await SharedPreferences.getInstance();

    if (newPasswordController.text != confirmPasswordController.text) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("password_mismatch"))),
      );
      return;
    }

    await prefs.setString("password", newPasswordController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageHelper.t("password_reset_success"))),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text(LanguageHelper.t("forgot_password")),
        backgroundColor: Colors.pinkAccent,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: SingleChildScrollView(
          child: Column(children: [

            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: LanguageHelper.t("email"),
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loadQuestion,
              child: Text(LanguageHelper.t("load_question")),
            ),

            const SizedBox(height: 25),

            if (questionLoaded)
              Column(children: [

                Text(
                  LanguageHelper.t(securityQuestion),
                  style: const TextStyle(fontSize: 16,fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: answerController,
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t("enter_answer"),
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                ElevatedButton(
                  onPressed: verifyAnswer,
                  child: Text(LanguageHelper.t("verify_answer")),
                ),
              ]),

            const SizedBox(height: 20),

            if (allowReset)
              Column(children: [

                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t("new_password"),
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t("confirm_password"),
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: resetPassword,
                  child: Text(LanguageHelper.t("reset_password")),
                ),
              ])

          ]),
        ),
      ),
    );
  }
}