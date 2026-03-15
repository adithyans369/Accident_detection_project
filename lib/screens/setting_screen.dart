import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../main.dart';
import '../utils/language_helper.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {

  String selectedLanguage = "English";

  @override
  void initState() {
    super.initState();
    loadLanguage();
  }

  /// Load saved language
  Future<void> loadLanguage() async {

    final prefs = await SharedPreferences.getInstance();
    String lang = prefs.getString("language") ?? "English";

    setState(() {
      selectedLanguage = lang;
    });

  }

  /// Change language
  Future<void> changeLanguage(String lang) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("language", lang);

    setState(() {
      selectedLanguage = lang;
    });

    if (lang == "English") {
      MyApp.setLocale(context, const Locale('en'));
    } else {
      MyApp.setLocale(context, const Locale('ml'));
    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xfffde6e6),

      appBar: AppBar(
        title: Text(LanguageHelper.t("settings")),
        backgroundColor: Colors.redAccent,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            /// Language
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(LanguageHelper.t("language")),

              trailing: DropdownButton<String>(
                value: selectedLanguage,

                items: const [

                  DropdownMenuItem(
                    value: "English",
                    child: Text("English"),
                  ),

                  DropdownMenuItem(
                    value: "Malayalam",
                    child: Text("Malayalam"),
                  ),

                ],

                onChanged: (value) {
                  changeLanguage(value!);
                },

              ),
            ),

            const Divider(),

            /// Help & Support
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: Text(LanguageHelper.t("help_support")),

              onTap: () {

                showDialog(
                  context: context,
                  builder: (context) {

                    return AlertDialog(

                      title: Text(LanguageHelper.t("help_support")),

                      content: Text(
                        LanguageHelper.t("help_message"),
                      ),

                    );

                  },
                );

              },
            ),

            const Divider(),

            /// Emergency contacts
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(LanguageHelper.t("emergency_contacts")),

              onTap: () {

                showDialog(
                  context: context,
                  builder: (context) {

                    return AlertDialog(

                      title: Text(LanguageHelper.t("emergency_contacts")),

                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          Text("🚑 ${LanguageHelper.t("ambulance")}: 108"),
                          Text("🚓 ${LanguageHelper.t("police")}: 100"),
                          Text("🚒 ${LanguageHelper.t("fire_force")}: 101"),

                        ],
                      ),

                    );

                  },
                );

              },
            ),

            const Divider(),

            /// Logout
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(LanguageHelper.t("logout")),

              onTap: () {

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );

              },
            ),

          ],
        ),
      ),
    );
  }
}