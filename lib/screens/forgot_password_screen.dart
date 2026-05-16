import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../utils/language_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {

  static const platform = MethodChannel('com.example.a4safe_pulse/sms');

  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String generatedOtp = "";
  bool otpSent = false;
  bool allowReset = false;

  bool _isValidPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10;
  }

  Future<void> _sendOtp() async {
    final prefs = await SharedPreferences.getInstance();

    final registeredPhone = prefs.getString("mobile") ?? "";
    final enteredPhone = phoneController.text.trim();

    if (enteredPhone.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("enter_phone"))),
      );
      return;
    }

    if (!_isValidPhone(enteredPhone)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("valid_phone"))),
      );
      return;
    }

    if (registeredPhone.isEmpty || enteredPhone != registeredPhone) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("phone_not_found"))),
      );
      return;
    }

    final smsPermission = await Permission.sms.request();
    if (!smsPermission.isGranted) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("sms_permission_needed"))),
      );
      return;
    }

    generatedOtp = (Random().nextInt(900000) + 100000).toString();

    try {
      await platform.invokeMethod('sendSMS', {
        'phone': enteredPhone,
        'message': 'Your A4 Safe Pulse OTP is $generatedOtp',
      });

      if (!mounted) return;
      setState(() {
        otpSent = true;
        allowReset = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("otp_sent"))),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("otp_send_failed"))),
      );
    }
  }

  void _verifyOtp() {
    if (otpController.text.trim() != generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("incorrect_otp"))),
      );
      return;
    }

    setState(() {
      allowReset = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageHelper.t("otp_verified"))),
    );
  }

  Future<void> resetPassword() async {
    final prefs = await SharedPreferences.getInstance();

    if (newPasswordController.text != confirmPasswordController.text) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageHelper.t("password_mismatch"))),
      );
      return;
    }

    await prefs.setString("password", newPasswordController.text);

    if (!mounted) return;
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
              controller: phoneController,
              decoration: InputDecoration(
                labelText: LanguageHelper.t("phone_number"),
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _sendOtp,
              child: Text(LanguageHelper.t("send_otp")),
            ),

            const SizedBox(height: 25),

            if (otpSent)
              Column(children: [

                TextField(
                  controller: otpController,
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t("enter_otp"),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 15),

                ElevatedButton(
                  onPressed: _verifyOtp,
                  child: Text(LanguageHelper.t("verify_otp")),
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
