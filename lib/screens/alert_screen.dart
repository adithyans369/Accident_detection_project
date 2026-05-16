import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
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
  String bloodGroup = "";
  String allergy = "";
  String timeNow = "";
  String emergency1 = "";
  String emergency2 = "";
  String gpsLink = "Fetching location...";

  int countdown = 10;
  bool alertSent = false;
  bool userAcknowledged = false;
  int smsSentCount = 0;
  String statusText = "Preparing...";

  final AudioPlayer alarmPlayer = AudioPlayer();

  // Call state
  bool isCalling = false;
  int callIndex = 0;
  Timer? callTimer;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _requestPermissions();
    await _loadUserData();
    _getCurrentTime();
    await _startAlarm();
    _startCountdown();
    _getGPSLocation();
  }

  // ─── PERMISSIONS ─────────────────────────────────────────
  Future<void> _requestPermissions() async {
    await Permission.sms.request();
    await Permission.phone.request();
    await Permission.location.request();
  }

  // ─── ALARM ───────────────────────────────────────────────
  Future<void> _startAlarm() async {
    await alarmPlayer.setReleaseMode(ReleaseMode.loop);
    await alarmPlayer.setVolume(1.0);
    await alarmPlayer.play(AssetSource('sounds/alarm.mpeg'));
  }

  Future<void> _stopAlarm() async {
    await alarmPlayer.stop();
  }

  Future<void> _lowerAlarm() async {
    await alarmPlayer.setVolume(0.2);
  }

  Future<void> _raiseAlarm() async {
    await alarmPlayer.setVolume(1.0);
  }

  // ─── GPS ─────────────────────────────────────────────────
  Future<void> _getGPSLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { gpsLink = "Location denied"; });
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          Position? last = await Geolocator.getLastKnownPosition();
          return last ?? Position(
            longitude: 0, latitude: 0,
            timestamp: DateTime.now(),
            accuracy: 0, altitude: 0,
            altitudeAccuracy: 0, heading: 0,
            headingAccuracy: 0, speed: 0, speedAccuracy: 0,
          );
        },
      );

      if (mounted) {
        setState(() {
          gpsLink =
          "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
        });
      }
    } catch (e) {
      if (mounted) setState(() { gpsLink = "Location unavailable"; });
    }
  }

  // ─── COUNTDOWN ───────────────────────────────────────────
  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() { countdown--; });
      if (countdown == 0) {
        await _startEmergencyProtocol();
        return false;
      }
      return true;
    });
  }

  // ─── EMERGENCY PROTOCOL ──────────────────────────────────
  Future<void> _startEmergencyProtocol() async {
    if (userAcknowledged) return;
    if (mounted) setState(() {
      alertSent = true;
      statusText = "🚨 Sending SMS...";
    });

    // 1. Send ONE SMS to both contacts
    await _sendSMSToAll();

    // 2. Start call loop
    _startCallLoop();
  }

  // ─── SMS — sent ONCE to both ─────────────────────────────
  Future<void> _sendSMSToAll() async {
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
      // Send to both simultaneously
      await Future.wait([
        if (emergency1.isNotEmpty)
          platform.invokeMethod('sendSMS', {
            'phone': emergency1,
            'message': message,
          }),
        if (emergency2.isNotEmpty)
          platform.invokeMethod('sendSMS', {
            'phone': emergency2,
            'message': message,
          }),
      ]);

      if (mounted) setState(() {
        smsSentCount++;
        statusText = "✅ SMS sent to both contacts!";
      });
      print("✅ SMS sent to both!");

    } catch (e) {
      print("❌ SMS error: $e");
      if (mounted) setState(() {
        statusText = "❌ SMS error: $e";
      });
    }
  }

  // ─── CALL LOOP ───────────────────────────────────────────
  void _startCallLoop() {
    // Call immediately
    _makeNextCall();

    // Then call every 15 seconds (10 sec call + 5 sec gap)
    callTimer = Timer.periodic(
      const Duration(seconds: 15),
          (timer) async {
        if (userAcknowledged) {
          timer.cancel();
          return;
        }
        await _makeNextCall();
      },
    );
  }

  Future<void> _makeNextCall() async {
    if (userAcknowledged) return;
    if (isCalling) return;

    // Build contact list
    List<String> contacts = [];
    if (emergency1.isNotEmpty) contacts.add(emergency1);
    if (emergency2.isNotEmpty) contacts.add(emergency2);
    if (contacts.isEmpty) return;

    // Round robin between contacts
    String numberToCall = contacts[callIndex % contacts.length];
    callIndex++;

    isCalling = true;

    // Lower alarm during call
    await _lowerAlarm();

    if (mounted) setState(() {
      statusText = "📞 Calling Contact ${callIndex % 2 == 1 ? '1' : '2'}...";
    });

    print("📞 Calling: $numberToCall");
    await FlutterPhoneDirectCaller.callNumber(numberToCall);

    // Wait 10 seconds for pickup
    await Future.delayed(const Duration(seconds: 10));

    // Raise alarm after call
    await _raiseAlarm();

    if (mounted) setState(() {
      statusText = "📞 Switching contact...";
    });

    isCalling = false;
  }

  // ─── USER IS OKAY ────────────────────────────────────────
  Future<void> _userIsOkay() async {
    userAcknowledged = true;
    callTimer?.cancel();
    await _stopAlarm();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ You are safe! All alerts stopped."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
    }
  }

  // ─── LOAD DATA ───────────────────────────────────────────
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        driverName = prefs.getString("name") ?? "Unknown";
        vehicleNumber = prefs.getString("vehicle") ?? "Not set";
        bloodGroup = prefs.getString("blood") ?? "Not set";
        allergy = prefs.getString("allergy") ?? "None";
        emergency1 = prefs.getString("emergency1") ?? "";
        emergency2 = prefs.getString("emergency2") ?? "";
      });
    }
  }

  void _getCurrentTime() {
    if (mounted) {
      setState(() {
        timeNow = DateFormat('hh:mm a').format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    callTimer?.cancel();
    alarmPlayer.dispose();
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

                const SizedBox(height: 10),

                Center(
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: const Center(
                      child: Text(
                        "ACCIDENT\nDETECTED",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    alertSent
                        ? "🚨 Emergency Active!\n$statusText"
                        : "⚠️ Sending in $countdown seconds...",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

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
                    subtitle: Text(
                      gpsLink,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text("Time"),
                    subtitle: Text(timeNow),
                  ),
                ),

                const SizedBox(height: 25),

                // I AM OKAY button
                SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 32),
                    label: const Text(
                      "I AM OKAY\nSTOP ALL ALERTS",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _userIsOkay,
                  ),
                ),

                const SizedBox(height: 15),

                // Send now button
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
                      if (!alertSent) _startEmergencyProtocol();
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