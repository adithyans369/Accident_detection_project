import 'package:flutter/material.dart';

class InputField extends StatelessWidget {

  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;

  const InputField({
    super.key,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {

    return TextField(
      controller: controller,
      obscureText: obscureText,

      decoration: InputDecoration(
        hintText: hint,

        prefixIcon: Icon(icon),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}