import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';
import '../utils/ml_classifier.dart';
import 'alert_screen.dart';
import 'user_profile_screen.dart';
import 'setting_screen.dart';

// BLE UUIDs - must match ESP32 code exactly
const String targetDeviceName = "A4SafePulse";
const String serviceUuid = "12345678-1234-1234-1234-123456789012";
const String characteristicUuid = "87654321-4321-4321-4321-210987654321";
const int accidentClassThreshold = 3;
const int expectedAnomalySamples = 50;

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

  StreamSubscription<List<ScanResult>>? scanResultsSubscription;
  StreamSubscription<bool>? scanningSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionStateSubscription;
  StreamSubscription<List<int>>? sensorValueSubscription;

  // ML
  final MLClassifier classifier = MLClassifier();

  // Buffer to collect incoming BLE data
  List<List<double>> sensorBuffer = [];
  bool isProcessing = false;
  int receivedSamplesInBatch = 0;
  int completedBatches = 0;
  int? lastMlResult;
  String lastPacket = "Waiting for sensor data";
  String mlStatus = "No ML result yet";
  String systemStatus = "Waiting for data...";

  @override
  void initState() {
    super.initState();
    loadUserData();
    classifier.init();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      driverName =
          prefs.getString("name") ?? LanguageHelper.t("unknown_driver");
      vehicleNumber = prefs.getString("vehicle") ?? LanguageHelper.t("not_set");
    });
  }

  Future<bool> requestBlePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final hasBluetoothScan =
        statuses[Permission.bluetoothScan]?.isGranted ?? true;
    final hasBluetoothConnect =
        statuses[Permission.bluetoothConnect]?.isGranted ?? true;
    final hasLocation = statuses[Permission.location]?.isGranted ?? true;

    if (!hasBluetoothScan || !hasBluetoothConnect || !hasLocation) {
      if (mounted) {
        setState(() {
          bleStatus = "Bluetooth and location permissions are required.";
          systemStatus = "Waiting for data...";
        });
      }
      return false;
    }

    return true;
  }

  bool isTargetDevice(ScanResult result) {
    final platformName = result.device.platformName;
    final advertisedName = result.advertisementData.advName;
    final advertisesService = result.advertisementData.serviceUuids
        .any((uuid) => uuid.toString().toLowerCase() == serviceUuid);

    return platformName == targetDeviceName ||
        advertisedName == targetDeviceName ||
        advertisesService;
  }

  // START BLE SCAN
  Future<void> startScan() async {
    if (isScanning) return;

    final hasPermissions = await requestBlePermissions();
    if (!mounted || !hasPermissions) return;

    await scanResultsSubscription?.cancel();
    await scanningSubscription?.cancel();

    setState(() {
      isScanning = true;
      bleStatus = "Scanning...";
      systemStatus = "Waiting for data...";
    });

    scanResultsSubscription =
        FlutterBluePlus.scanResults.listen((results) async {
      if (isConnected) return;
      for (ScanResult result in results) {
        if (isTargetDevice(result)) {
          await FlutterBluePlus.stopScan();
          if (!mounted || isConnected) return;
          await connectToDevice(result.device);
          break;
        }
      }
    });

    // If scan ends without finding device
    scanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && !isConnected) {
        if (mounted) {
          setState(() {
            isScanning = false;
            bleStatus = "Device not found. Try again.";
            systemStatus = "Waiting for data...";
          });
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      if (mounted) {
        setState(() {
          isScanning = false;
          bleStatus = "Scan failed: $e";
          systemStatus = "Waiting for data...";
        });
      }
    }
  }

  // CONNECT TO ESP32
  Future<void> connectToDevice(BluetoothDevice device) async {
    await connectionStateSubscription?.cancel();

    setState(() {
      bleStatus = "Connecting...";
      systemStatus = "Connected to ESP...";
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      try {
        await device.requestMtu(185);
      } catch (_) {
        // MTU requests are Android-specific; default MTU is still usable.
      }

      if (!mounted) return;
      setState(() {
        connectedDevice = device;
        isConnected = true;
        isScanning = false;
        bleStatus = "Connected to $targetDeviceName ✅";
        systemStatus = "Connected to ESP...";
      });

      // Listen for disconnection
      connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (mounted) {
            setState(() {
              isConnected = false;
              bleStatus = "Disconnected ❌";
              characteristic = null;
              systemStatus = "Waiting for data...";
            });
          }
          sensorValueSubscription?.cancel();
          sensorBuffer.clear();
          receivedSamplesInBatch = 0;
        }
      });

      // Discover services
      await discoverServices(device);
    } catch (e) {
      if (mounted) {
        setState(() {
          bleStatus = "Connection failed: $e";
          isScanning = false;
          systemStatus = "Waiting for data...";
        });
      }
    }
  }

  // DISCOVER BLE SERVICES
  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toLowerCase() == characteristicUuid) {
            characteristic = c;
            await c.setNotifyValue(true);

            await sensorValueSubscription?.cancel();

            // LISTEN FOR INCOMING DATA
            sensorValueSubscription = c.onValueReceived.listen((value) {
              String incoming = String.fromCharCodes(value);
              handleIncomingData(incoming);
            });

            if (mounted) {
              setState(() {
                systemStatus = "Waiting for data...";
              });
            }
            debugPrint("✅ Characteristic found and subscribed!");
            return;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        bleStatus = "ESP32 service not found. Check UUIDs.";
        systemStatus = "Waiting for data...";
      });
    }
  }

  Color get statusColor {
    if (!isConnected) return Colors.redAccent;
    if (systemStatus.contains("No Accident")) return Colors.green;
    if (systemStatus.contains("Accident")) return Colors.red;
    if (systemStatus.contains("Running") || systemStatus.contains("Anomaly")) {
      return Colors.orange;
    }
    return Colors.green;
  }

  IconData get statusIcon {
    if (!isConnected) return Icons.bluetooth_disabled;
    if (systemStatus.contains("No Accident")) return Icons.check_circle;
    if (systemStatus.contains("Accident")) return Icons.warning;
    if (systemStatus.contains("Running")) {
      return Icons.memory;
    }
    if (systemStatus.contains("Anomaly")) {
      return Icons.sensors;
    }
    return Icons.bluetooth_connected;
  }

  // HANDLE INCOMING BLE DATA
  void handleIncomingData(String data) {
    if (!monitoring || isProcessing) return;

    data = data.trim();
    if (data.isEmpty) return;

    if (data == "ANOMALY") {
      sensorBuffer.clear();
      if (mounted) {
        setState(() {
          receivedSamplesInBatch = 0;
          lastPacket = "ANOMALY received";
          mlStatus = "ESP anomaly detected";
          systemStatus = "Anomaly data received!";
        });
      }
    } else if (data == "END") {
      // Buffer complete - run ML
      debugPrint("Buffer complete! ${sensorBuffer.length} readings received");
      if (mounted) {
        setState(() {
          lastPacket = "END received";
          completedBatches++;
          systemStatus = "Running prediction model...";
          mlStatus = "Preparing ML prediction";
        });
      }
      runMLPrediction();
    } else {
      // Parse CSV line: ax,ay,az,gx,gy,gz
      try {
        List<String> parts = data.split(",").map((e) => e.trim()).toList();
        if (parts.length == 6) {
          List<double> reading = parts.map((e) => double.parse(e)).toList();
          sensorBuffer.add(reading);
          if (mounted) {
            setState(() {
              receivedSamplesInBatch = sensorBuffer.length;
              lastPacket = data;
              systemStatus = "Anomaly data received!";
            });
          }
        }
      } catch (e) {
        debugPrint("Parse error: $e");
        if (mounted) {
          setState(() {
            lastPacket = "Parse error: $data";
          });
        }
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

      accMag.add(sqrt(ax * ax + ay * ay + az * az));
      gyroMag.add(sqrt(gx * gx + gy * gy + gz * gz));
    }

    // Helper functions
    double mean(List<double> vals) =>
        vals.reduce((a, b) => a + b) / vals.length;

    double std(List<double> vals) {
      double m = mean(vals);
      double variance =
          vals.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) /
              vals.length;
      return sqrt(variance);
    }

    double energy(List<double> vals) =>
        vals.map((v) => v * v).reduce((a, b) => a + b);

    // Jerk = rate of change of acceleration
    List<double> jerk = [];
    for (int i = 1; i < accMag.length; i++) {
      jerk.add((accMag[i] - accMag[i - 1]).abs());
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

  bool isAccidentPrediction(int result) {
    // Supports both binary models (1 = accident) and multiclass models
    // where 3+ represents minor/major/critical accident classes.
    return result == 1 || result >= accidentClassThreshold;
  }

  // RUN ML MODEL
  Future<void> runMLPrediction() async {
    if (sensorBuffer.isEmpty) return;
    isProcessing = true;

    try {
      if (mounted) {
        setState(() {
          systemStatus = "Running prediction model...";
          mlStatus = "Extracting features";
        });
      }
      Map<String, double> features = extractFeatures(sensorBuffer);
      debugPrint("Features: $features");

      if (mounted) {
        setState(() {
          systemStatus = "Running accident detection model";
          mlStatus = "Running ML model";
        });
      }

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

      debugPrint("ML Result: $result");
      final shouldAlert = isAccidentPrediction(result);
      if (mounted) {
        setState(() {
          lastMlResult = result;
          mlStatus = shouldAlert
              ? "Prediction: Accident (Sending SOS)"
              : "Prediction: No Accident";
          systemStatus = mlStatus;
        });
      }

      if (shouldAlert && mounted) {
        // ACCIDENT DETECTED → go to alert screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AlertScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint("ML Error: $e");
      if (mounted) {
        setState(() {
          mlStatus = "ML error: $e";
          systemStatus = "ML prediction error";
        });
      }
    } finally {
      // Clear buffer for next reading
      sensorBuffer.clear();
      receivedSamplesInBatch = 0;
      isProcessing = false;
    }
  }

  // DISCONNECT
  Future<void> disconnect() async {
    await sensorValueSubscription?.cancel();
    await connectionStateSubscription?.cancel();
    await connectedDevice?.disconnect();
    sensorBuffer.clear();
    receivedSamplesInBatch = 0;
    if (mounted) {
      setState(() {
        isConnected = false;
        bleStatus = "Disconnected";
        connectedDevice = null;
        characteristic = null;
        systemStatus = "Waiting for data...";
      });
    }
  }

  Widget buildSystemStatusBar() {
    final color = statusColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              systemStatus,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    scanResultsSubscription?.cancel();
    scanningSubscription?.cancel();
    connectionStateSubscription?.cancel();
    sensorValueSubscription?.cancel();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            buildSystemStatusBar(),

            const SizedBox(height: 15),

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
                          isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
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
                          backgroundColor:
                              isConnected ? Colors.grey : Colors.blue,
                        ),
                        icon: Icon(isConnected
                            ? Icons.bluetooth_disabled
                            : Icons.bluetooth),
                        label: Text(
                          isConnected
                              ? "Disconnect"
                              : (isScanning
                                  ? "Scanning..."
                                  : "Connect to ESP32"),
                        ),
                        onPressed: isScanning
                            ? null
                            : (isConnected ? disconnect : startScan),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // BLE + ML DIAGNOSTICS
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
                    const Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.deepPurple),
                        SizedBox(width: 10),
                        Text(
                          "BLE / ML Status",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Samples in current batch: "
                      "$receivedSamplesInBatch / $expectedAnomalySamples",
                    ),
                    Text("Completed batches: $completedBatches"),
                    Text("Last ML result: ${lastMlResult ?? '-'}"),
                    Text("ML status: $mlStatus"),
                    const SizedBox(height: 8),
                    Text(
                      "Last packet: $lastPacket",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                      activeThumbColor: Colors.green,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
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
