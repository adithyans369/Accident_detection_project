import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {

  bool isEditing = false;

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final bloodController = TextEditingController();
  final mobileController = TextEditingController();
  final vehicleController = TextEditingController();
  final addressController = TextEditingController();
  final emergency1Controller = TextEditingController();
  final emergency2Controller = TextEditingController();
  final allergyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {

    final prefs = await SharedPreferences.getInstance();

    nameController.text = prefs.getString("name") ?? "";
    ageController.text = prefs.getString("age") ?? "";
    bloodController.text = prefs.getString("blood") ?? "";
    mobileController.text = prefs.getString("mobile") ?? "";
    vehicleController.text = prefs.getString("vehicle") ?? "";
    addressController.text = prefs.getString("address") ?? "";
    emergency1Controller.text = prefs.getString("emergency1") ?? "";
    emergency2Controller.text = prefs.getString("emergency2") ?? "";
    allergyController.text = prefs.getString("allergy") ?? "";
  }

  Future<void> saveProfile() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("name", nameController.text);
    await prefs.setString("age", ageController.text);
    await prefs.setString("blood", bloodController.text);
    await prefs.setString("mobile", mobileController.text);
    await prefs.setString("vehicle", vehicleController.text);
    await prefs.setString("address", addressController.text);
    await prefs.setString("emergency1", emergency1Controller.text);
    await prefs.setString("emergency2", emergency2Controller.text);
    await prefs.setString("allergy", allergyController.text);

    setState(() {
      isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageHelper.t("profile_updated"))),
    );
  }

  Widget field(String label, IconData icon, TextEditingController controller) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),

      child: TextField(
        controller: controller,
        enabled: isEditing,

        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),

          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFFFF1F2),

      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text(LanguageHelper.t("user_profile")),

        actions: [

          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),

            onPressed: () {

              if (isEditing) {
                saveProfile();
              } else {
                setState(() {
                  isEditing = true;
                });
              }

            },
          )

        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [

          field(LanguageHelper.t("name"), Icons.person, nameController),
          field(LanguageHelper.t("age"), Icons.cake, ageController),
          field(LanguageHelper.t("blood_group"), Icons.bloodtype, bloodController),
          field(LanguageHelper.t("mobile_number"), Icons.phone, mobileController),
          field(LanguageHelper.t("vehicle_number"), Icons.directions_car, vehicleController),
          field(LanguageHelper.t("address"), Icons.home, addressController),
          field(LanguageHelper.t("emergency_contact1"), Icons.contact_phone, emergency1Controller),
          field(LanguageHelper.t("emergency_contact2"), Icons.contact_phone, emergency2Controller),
          field(LanguageHelper.t("allergies"), Icons.warning, allergyController),

        ],
      ),
    );
  }
}