import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/language_helper.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {

  String driverName = "";
  String vehicleNumber = "";
  String location = "";
  String timeNow = "";

  int countdown = 10;

  final AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    loadUserData();
    getCurrentTime();
    startAlarm();
    startCountdown();
  }

  /// PLAY ALARM
  Future<void> startAlarm() async {
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('sounds/alarm.mpeg'));
  }

  /// STOP ALARM
  Future<void> stopAlarm() async {
    await player.stop();
  }

  /// COUNTDOWN TIMER
  void startCountdown() {

    Future.doWhile(() async {

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return false;

      setState(() {
        countdown--;
      });

      if (countdown == 0) {

        await stopAlarm();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageHelper.t("sending_alert")),
          ),
        );

        /// SMS will be added here later

        return false;
      }

      return true;

    });

  }

  /// LOAD DRIVER DATA
  Future<void> loadUserData() async {

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      driverName = prefs.getString("name") ?? LanguageHelper.t("unknown_driver");
      vehicleNumber = prefs.getString("vehicle") ?? LanguageHelper.t("not_set");
      location = prefs.getString("address") ?? LanguageHelper.t("location_unknown");
    });

  }

  /// CURRENT TIME
  void getCurrentTime() {

    final now = DateTime.now();

    setState(() {
      timeNow = DateFormat('hh:mm a').format(now);
    });

  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFFFF1F2),

      appBar: AppBar(
        title: Text(LanguageHelper.t("accident_alert")),
        backgroundColor: Colors.redAccent,
      ),

      body: SingleChildScrollView(

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const SizedBox(height: 20),

              /// Accident Circle
              Center(
                child: Container(
                  height: 180,
                  width: 180,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                  ),

                  child: Center(
                    child: Text(
                      LanguageHelper.t("accident_detected"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// Countdown
              Text(
                "${LanguageHelper.t("sending_in")} $countdown ${LanguageHelper.t("seconds")}",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(LanguageHelper.t("driver")),
                  subtitle: Text(driverName),
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text(LanguageHelper.t("vehicle")),
                  subtitle: Text(vehicleNumber),
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(LanguageHelper.t("location")),
                  subtitle: Text(location),
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(LanguageHelper.t("time")),
                  subtitle: Text(timeNow),
                ),
              ),

              const SizedBox(height: 30),

              /// SEND ALERT
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 50),
                ),

                onPressed: () async {

                  await stopAlarm();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LanguageHelper.t("alert_sent")),
                    ),
                  );

                },

                child: Text(LanguageHelper.t("send_alert")),
              ),

              const SizedBox(height: 10),

              /// CANCEL
              OutlinedButton(

                onPressed: () async {

                  await stopAlarm();
                  Navigator.pop(context);

                },

                child: Text(LanguageHelper.t("cancel")),
              ),

              const SizedBox(height: 20),

            ],
          ),
        ),
      ),
    );
  }
}