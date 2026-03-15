import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/language_helper.dart';
import 'user_profile_screen.dart';
import 'setting_screen.dart';
import 'alert_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String driverName = "";
  String vehicleNumber = "";

  bool monitoring = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      driverName = prefs.getString("name") ??
          LanguageHelper.t("unknown_driver");

      vehicleNumber = prefs.getString("vehicle") ??
          LanguageHelper.t("not_set");
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xfffde6e6),

      appBar: AppBar(

        title: const Text("A4 Safe Pulse"),

        backgroundColor: Colors.redAccent,

        actions: [

          /// USER PROFILE
          IconButton(
            icon: const Icon(Icons.person),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const UserProfileScreen(),
                ),
              );
            },
          ),

          /// SETTINGS
          IconButton(
            icon: const Icon(Icons.settings),

            onPressed: () async {

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const SettingScreen(),
                ),
              );

              /// Rebuild screen after returning
              setState(() {});

            },
          ),

        ],
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const SizedBox(height: 10),

            /// DRIVER CARD
            Card(

              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),

              child: Padding(

                padding: const EdgeInsets.all(16),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Row(

                      children: [

                        const Icon(Icons.person,
                            color: Colors.red),

                        const SizedBox(width: 10),

                        Text(
                          "${LanguageHelper.t("driver")}: $driverName",

                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(

                      children: [

                        const Icon(Icons.directions_car,
                            color: Colors.blue),

                        const SizedBox(width: 10),

                        Text(
                          "${LanguageHelper.t("vehicle")}: $vehicleNumber",

                          style: const TextStyle(fontSize: 16),
                        ),

                      ],
                    ),

                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            /// MONITORING STATUS
            Card(

              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),

              child: Padding(

                padding: const EdgeInsets.all(16),

                child: Row(

                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,

                  children: [

                    Text(
                      LanguageHelper.t("monitoring_status"),

                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Switch(

                      value: monitoring,

                      activeColor: Colors.green,

                      onChanged: (value) {
                        setState(() {
                          monitoring = value;
                        });
                      },

                    ),

                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            /// EMERGENCY NUMBERS
            Text(
              LanguageHelper.t("emergency_numbers"),

              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(Icons.local_hospital,
                    color: Colors.red),
                title: Text(LanguageHelper.t("ambulance")),
                subtitle: const Text("108"),
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.local_police,
                    color: Colors.blue),
                title: Text(LanguageHelper.t("police")),
                subtitle: const Text("100"),
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.local_fire_department,
                    color: Colors.orange),
                title: Text(LanguageHelper.t("fire_force")),
                subtitle: const Text("101"),
              ),
            ),

            const SizedBox(height: 30),

            /// TEST ALERT BUTTON
            Center(

              child: ElevatedButton.icon(

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 12),
                ),

                icon: const Icon(Icons.warning),

                label: Text(
                  LanguageHelper.t("send_alert"),
                  style: const TextStyle(fontSize: 16),
                ),

                onPressed: () {

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const AlertScreen(),
                    ),
                  );

                },

              ),
            ),

          ],
        ),
      ),
    );
  }
}