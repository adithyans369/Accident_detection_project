import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/language_helper.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {

  static const platform = MethodChannel('com.example.a4safe_pulse/sms');

  String driverName = "";
  String vehicleNumber = "";
  String location = "";
  String bloodGroup = "";
  String allergy = "";
  String timeNow = "";
  String emergency1 = "";
  String emergency2 = "";
  String gpsLink = "Fetching location...";

  int countdown = 10;
  bool alertSent = false;
  bool userAcknowledged = false;

  final AudioPlayer player = AudioPlayer();
  final FlutterTts tts = FlutterTts();

  Timer? smsTimer;
  Timer? callTimer;
  Timer? flashTimer;

  bool isFlashOn = false;
  bool isCalling = false;
  int callContactIndex = 0;
  int smsSentCount = 0;

  @override
  void initState() {
    super.initState();
    initAll();
  }

  Future<void> initAll() async {
    await loadUserData();
    getCurrentTime();
    startAlarm();
    startVibration();
    startFlashlight();
    startCountdown();
    getGPSLocation();
  }

  // ─── ALARM ───────────────────────────────────────────────
  Future<void> startAlarm() async {
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(1.0);
    await player.play(AssetSource('sounds/alarm.mpeg'));
  }

  Future<void> stopAlarm() async {
    await player.stop();
  }

  Future<void> lowerAlarmVolume() async {
    await player.setVolume(0.2);
  }

  // ─── VIBRATION ───────────────────────────────────────────
  Future<void> startVibration() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [500, 1000, 500, 1000],
        repeat: 0,
      );
    }
  }

  Future<void> stopVibration() async {
    Vibration.cancel();
  }

  // ─── FLASHLIGHT ──────────────────────────────────────────
  void startFlashlight() {
    flashTimer = Timer.periodic(
      const Duration(milliseconds: 500),
          (timer) async {
        if (userAcknowledged) {
          timer.cancel();
          try {
            await TorchLight.disableTorch();
          } catch (_) {}
          return;
        }
        try {
          if (isFlashOn) {
            await TorchLight.disableTorch();
          } else {
            await TorchLight.enableTorch();
          }
          isFlashOn = !isFlashOn;
        } catch (_) {}
      },
    );
  }

  Future<void> stopFlashlight() async {
    flashTimer?.cancel();
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
  }

  // ─── GPS ─────────────────────────────────────────────────
  Future<void> getGPSLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() { gpsLink = "Location permission denied"; });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => Geolocator.getLastKnownPosition().then(
              (pos) => pos ?? Position(
            longitude: 0,
            latitude: 0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
      );

      String link =
          "https://maps.google.com/?q=${position.latitude},${position.longitude}";
      if (mounted) setState(() { gpsLink = link; });

    } catch (e) {
      if (mounted) setState(() { gpsLink = "Location unavailable"; });
    }
  }

  // ─── SMS ─────────────────────────────────────────────────
  Future<void> sendEmergencySMS() async {
    String message =
        "🚨 ACCIDENT DETECTED! "
        "Driver: $driverName, "
        "Vehicle: $vehicleNumber, "
        "Blood Group: $bloodGroup, "
        "Allergies: $allergy, "
        "Time: $timeNow, "
        "Location: $gpsLink. "
        "Please respond immediately!";

    try {
      if (emergency1.isNotEmpty) {
        await platform.invokeMethod('sendSMS', {
          'phone': emergency1,
          'message': message,
        });
      }
      if (emergency2.isNotEmpty) {
        await platform.invokeMethod('sendSMS', {
          'phone': emergency2,
          'message': message,
        });
      }
      if (mounted) setState(() { smsSentCount++; });
      print("SMS sent! Count: $smsSentCount");
    } catch (e) {
      print("SMS failed: $e");
    }
  }

  // ─── WHATSAPP ────────────────────────────────────────────
  Future<void> sendWhatsApp(String phone, String message) async {
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
      if (!cleanPhone.startsWith('+')) {
        cleanPhone = '+91$cleanPhone';
      }
      final Uri whatsappUri = Uri.parse(
        "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}",
      );
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("WhatsApp failed: $e");
    }
  }

  Future<void> sendWhatsAppToAll() async {
    String message =
        "🚨 ACCIDENT DETECTED!\n"
        "Driver: $driverName\n"
        "Vehicle: $vehicleNumber\n"
        "Blood Group: $bloodGroup\n"
        "Allergies: $allergy\n"
        "Time: $timeNow\n"
        "Location: $gpsLink\n"
        "Please respond immediately!";

    if (emergency1.isNotEmpty) await sendWhatsApp(emergency1, message);
    await Future.delayed(const Duration(seconds: 2));
    if (emergency2.isNotEmpty) await sendWhatsApp(emergency2, message);
  }

  // ─── CALL ────────────────────────────────────────────────
  Future<void> makeEmergencyCall() async {
    if (userAcknowledged) return;
    if (isCalling) return;

    isCalling = true;

    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.speak(
      "Accident detected! Driver $driverName needs help! Calling emergency contact now!",
    );

    await Future.delayed(const Duration(seconds: 4));
    await lowerAlarmVolume();

    String numberToCall =
    callContactIndex == 0 ? emergency1 : emergency2;

    if (numberToCall.isNotEmpty) {
      print("Calling: $numberToCall");
      await FlutterPhoneDirectCaller.callNumber(numberToCall);
    }

    await Future.delayed(const Duration(seconds: 30));

    if (!userAcknowledged) {
      await player.setVolume(1.0);
      callContactIndex = callContactIndex == 0 ? 1 : 0;
      isCalling = false;
    }
  }

  // ─── COUNTDOWN ───────────────────────────────────────────
  void startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() { countdown--; });

      if (countdown == 0) {
        await startEmergencyProtocol();
        return false;
      }
      return true;
    });
  }

  // ─── MAIN EMERGENCY PROTOCOL ─────────────────────────────
  Future<void> startEmergencyProtocol() async {
    if (userAcknowledged) return;
    if (mounted) setState(() { alertSent = true; });

    await sendEmergencySMS();
    await sendWhatsAppToAll();

    smsTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (userAcknowledged) {
        timer.cancel();
        return;
      }
      await sendEmergencySMS();
    });

    await makeEmergencyCall();

    callTimer = Timer.periodic(const Duration(seconds: 35), (timer) async {
      if (userAcknowledged) {
        timer.cancel();
        return;
      }
      await makeEmergencyCall();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 Emergency protocol started!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── USER IS OKAY ────────────────────────────────────────
  Future<void> userIsOkay() async {
    userAcknowledged = true;

    smsTimer?.cancel();
    callTimer?.cancel();
    await stopAlarm();
    await stopVibration();
    await stopFlashlight();
    await tts.stop();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Alert cancelled. Stay safe!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
    }
  }

  // ─── LOAD DATA ───────────────────────────────────────────
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        driverName = prefs.getString("name") ?? "Unknown";
        vehicleNumber = prefs.getString("vehicle") ?? "Not set";
        location = prefs.getString("address") ?? "Unknown";
        bloodGroup = prefs.getString("blood") ?? "Not set";
        allergy = prefs.getString("allergy") ?? "None";
        emergency1 = prefs.getString("emergency1") ?? "";
        emergency2 = prefs.getString("emergency2") ?? "";
      });
    }
  }

  void getCurrentTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        timeNow = DateFormat('hh:mm a').format(now);
      });
    }
  }

  @override
  void dispose() {
    smsTimer?.cancel();
    callTimer?.cancel();
    flashTimer?.cancel();
    player.dispose();
    tts.stop();
    stopVibration();
    stopFlashlight();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF1F2),

        appBar: AppBar(
          title: const Text("🚨 ACCIDENT ALERT"),
          backgroundColor: Colors.red,
          automaticallyImplyLeading: false,
        ),

        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [

                const SizedBox(height: 20),

                // Accident circle
                Center(
                  child: Container(
                    height: 160,
                    width: 160,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: const Center(
                      child: Text(
                        "ACCIDENT\nDETECTED",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  alertSent
                      ? "🚨 Emergency protocol active!\nSMS sent: $smsSentCount times"
                      : "Sending alert in $countdown seconds...",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.red),
                    title: const Text("Driver"),
                    subtitle: Text(driverName),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_car, color: Colors.blue),
                    title: const Text("Vehicle"),
                    subtitle: Text(vehicleNumber),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bloodtype, color: Colors.red),
                    title: const Text("Blood Group"),
                    subtitle: Text(bloodGroup),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber, color: Colors.orange),
                    title: const Text("Allergies"),
                    subtitle: Text(allergy),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.green),
                    title: const Text("GPS Location"),
                    subtitle: Text(gpsLink),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text("Time"),
                    subtitle: Text(timeNow),
                  ),
                ),

                const SizedBox(height: 30),

                // I AM OKAY button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 28),
                    label: const Text(
                      "I AM OKAY - STOP ALERT",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: userIsOkay,
                  ),
                ),

                const SizedBox(height: 15),

                // Send alert now button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      alertSent ? Colors.grey : Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.send),
                    label: const Text(
                      "SEND ALERT NOW",
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      if (!alertSent) startEmergencyProtocol();
                    },
                  ),
                ),

                const SizedBox(height: 30),

              ],
            ),
          ),
        ),
      ),
    );
  }
}