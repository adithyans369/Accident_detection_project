import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';
import '../utils/ml_classifier.dart';
import 'alert_screen.dart';
import 'user_profile_screen.dart';
import 'setting_screen.dart';

// BLE UUIDs - must match ESP32 code exactly
const String SERVICE_UUID = "12345678-1234-1234-1234-123456789012";
const String CHARACTERISTIC_UUID = "87654321-4321-4321-4321-210987654321";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String driverName = "";
  String vehicleNumber = "";
  bool monitoring = true;

  // BLE state
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? characteristic;
  bool isScanning = false;
  bool isConnected = false;
  String bleStatus = "Not connected";

  // ML
  final MLClassifier classifier = MLClassifier();

  // Buffer to collect incoming BLE data
  List<List<double>> sensorBuffer = [];
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
    classifier.init();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      driverName = prefs.getString("name") ?? LanguageHelper.t("unknown_driver");
      vehicleNumber = prefs.getString("vehicle") ?? LanguageHelper.t("not_set");
    });
  }

  // START BLE SCAN
  Future<void> startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      bleStatus = "Scanning...";
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.platformName == "A4SafePulse") {
          await FlutterBluePlus.stopScan();
          await connectToDevice(result.device);
          break;
        }
      }
    });

    // If scan ends without finding device
    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && !isConnected) {
        if (mounted) {
          setState(() {
            isScanning = false;
            bleStatus = "Device not found. Try again.";
          });
        }
      }
    });
  }

  // CONNECT TO ESP32
  Future<void> connectToDevice(BluetoothDevice device) async {
    setState(() {
      bleStatus = "Connecting...";
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      setState(() {
        connectedDevice = device;
        isConnected = true;
        isScanning = false;
        bleStatus = "Connected to A4SafePulse ✅";
      });

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (mounted) {
            setState(() {
              isConnected = false;
              bleStatus = "Disconnected ❌";
              characteristic = null;
            });
          }
        }
      });

      // Discover services
      await discoverServices(device);

    } catch (e) {
      setState(() {
        bleStatus = "Connection failed: $e";
        isScanning = false;
      });
    }
  }

  // DISCOVER BLE SERVICES
  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString() == CHARACTERISTIC_UUID) {
            characteristic = c;
            await c.setNotifyValue(true);

            // LISTEN FOR INCOMING DATA
            c.onValueReceived.listen((value) {
              String incoming = String.fromCharCodes(value);
              handleIncomingData(incoming);
            });

            print("✅ Characteristic found and subscribed!");
            break;
          }
        }
      }
    }
  }

  // HANDLE INCOMING BLE DATA
  void handleIncomingData(String data) {
    if (!monitoring || isProcessing) return;

    data = data.trim();

    if (data == "END") {
      // Buffer complete - run ML
      print("Buffer complete! ${sensorBuffer.length} readings received");
      runMLPrediction();
    } else {
      // Parse CSV line: ax,ay,az,gx,gy,gz
      try {
        List<String> parts = data.split(",");
        if (parts.length == 6) {
          List<double> reading = parts.map((e) => double.parse(e)).toList();
          sensorBuffer.add(reading);
        }
      } catch (e) {
        print("Parse error: $e");
      }
    }
  }

  // EXTRACT 10 FEATURES FROM BUFFER
  Map<String, double> extractFeatures(List<List<double>> buffer) {
    List<double> accMag = [];
    List<double> gyroMag = [];

    for (var reading in buffer) {
      double ax = reading[0], ay = reading[1], az = reading[2];
      double gx = reading[3], gy = reading[4], gz = reading[5];

      accMag.add(sqrt(ax*ax + ay*ay + az*az));
      gyroMag.add(sqrt(gx*gx + gy*gy + gz*gz));
    }

    // Helper functions
    double mean(List<double> vals) =>
        vals.reduce((a, b) => a + b) / vals.length;

    double std(List<double> vals) {
      double m = mean(vals);
      double variance = vals.map((v) => (v - m) * (v - m))
          .reduce((a, b) => a + b) / vals.length;
      return sqrt(variance);
    }

    double energy(List<double> vals) =>
        vals.map((v) => v * v).reduce((a, b) => a + b);

    // Jerk = rate of change of acceleration
    List<double> jerk = [];
    for (int i = 1; i < accMag.length; i++) {
      jerk.add((accMag[i] - accMag[i-1]).abs());
    }

    return {
      'peak_acc': accMag.reduce(max),
      'mean_acc': mean(accMag),
      'std_acc': std(accMag),
      'acc_range': accMag.reduce(max) - accMag.reduce(min),
      'jerk_mean': jerk.isEmpty ? 0.0 : mean(jerk),
      'gyro_mean': mean(gyroMag),
      'gyro_std': std(gyroMag),
      'gyro_range': gyroMag.reduce(max) - gyroMag.reduce(min),
      'energy_acc': energy(accMag),
      'energy_gyro': energy(gyroMag),
    };
  }

  // RUN ML MODEL
  Future<void> runMLPrediction() async {
    if (sensorBuffer.isEmpty) return;
    isProcessing = true;

    try {
      Map<String, double> features = extractFeatures(sensorBuffer);
      print("Features: $features");

      int result = await classifier.predict(
        peakAcc: features['peak_acc']!,
        meanAcc: features['mean_acc']!,
        stdAcc: features['std_acc']!,
        accRange: features['acc_range']!,
        jerkMean: features['jerk_mean']!,
        gyroMean: features['gyro_mean']!,
        gyroStd: features['gyro_std']!,
        gyroRange: features['gyro_range']!,
        energyAcc: features['energy_acc']!,
        energyGyro: features['energy_gyro']!,
      );

      print("ML Result: $result");

      if (result == 1 && mounted) {
        // ACCIDENT DETECTED → go to alert screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AlertScreen(),
          ),
        );
      }

    } catch (e) {
      print("ML Error: $e");
    } finally {
      // Clear buffer for next reading
      sensorBuffer.clear();
      isProcessing = false;
    }
  }

  // DISCONNECT
  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    setState(() {
      isConnected = false;
      bleStatus = "Disconnected";
      connectedDevice = null;
      characteristic = null;
    });
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffde6e6),

      appBar: AppBar(
        title: const Text("A4 Safe Pulse"),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingScreen(),
                ),
              );
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

            // DRIVER CARD
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
                        const Icon(Icons.person, color: Colors.red),
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
                        const Icon(Icons.directions_car, color: Colors.blue),
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

            const SizedBox(height: 15),

            // BLE STATUS CARD
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
                        Icon(
                          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bleStatus,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isConnected ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected ? Colors.grey : Colors.blue,
                        ),
                        icon: Icon(isConnected ? Icons.bluetooth_disabled : Icons.bluetooth),
                        label: Text(
                          isConnected ? "Disconnect" : (isScanning ? "Scanning..." : "Connect to ESP32"),
                        ),
                        onPressed: isScanning ? null : (isConnected ? disconnect : startScan),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // MONITORING STATUS
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

            const SizedBox(height: 15),

            // EMERGENCY NUMBERS
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
                leading: const Icon(Icons.local_hospital, color: Colors.red),
                title: Text(LanguageHelper.t("ambulance")),
                subtitle: const Text("108"),
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.local_police, color: Colors.blue),
                title: Text(LanguageHelper.t("police")),
                subtitle: const Text("100"),
              ),
            ),

            const SizedBox(height: 20),

            // TEST ALERT BUTTON
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
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
                      builder: (context) => const AlertScreen(),
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