import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';
import '../utils/ml_classifier.dart';
import 'alert_screen.dart';
import 'user_profile_screen.dart';
import 'setting_screen.dart';

// ─── BLE UUIDs — must match ESP32 exactly ───────────────────────────────────
const String SERVICE_UUID     = "12345678-1234-1234-1234-123456789012";
const String CHAR_DATA_UUID   = "87654321-4321-4321-4321-210987654321";
const String CHAR_STATUS_UUID = "abcdef01-1234-1234-1234-abcdef012345";

// ─── STATUS MODEL ────────────────────────────────────────────────────────────
class Esp32Status {
  final String   state;
  final bool     mpuOk;
  final double   compositeScore;
  final bool     anomalyActive;
  final int      samplesInFlight;
  final DateTime lastSeen;

  const Esp32Status({
    required this.state,
    required this.mpuOk,
    required this.compositeScore,
    required this.anomalyActive,
    required this.samplesInFlight,
    required this.lastSeen,
  });

  factory Esp32Status.fromString(String raw) {
    final parts = Map.fromEntries(
      raw.split('|').map((p) {
        final kv = p.split(':');
        return MapEntry(kv[0], kv.length > 1 ? kv[1] : '');
      }),
    );
    return Esp32Status(
      state:           parts['STATUS']  ?? 'UNKNOWN',
      mpuOk:           parts['MPU']     == 'OK',
      compositeScore:  double.tryParse(parts['SCORE']   ?? '0') ?? 0,
      anomalyActive:   parts['ANOMALY'] == '1',
      samplesInFlight: int.tryParse(parts['SAMPLES'] ?? '0') ?? 0,
      lastSeen:        DateTime.now(),
    );
  }

  static Esp32Status get empty => Esp32Status(
    state: 'NOT CONNECTED',
    mpuOk: false,
    compositeScore: 0,
    anomalyActive: false,
    samplesInFlight: 0,
    lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String driverName    = "";
  String vehicleNumber = "";
  bool   monitoring    = true;

  // ── BLE ───────────────────────────────────────────────────────────────────
  BluetoothDevice?         connectedDevice;
  BluetoothCharacteristic? dataChar;
  BluetoothCharacteristic? statusChar;
  bool   isScanning  = false;
  bool   isConnected = false;
  String bleStatus   = "Not connected";

  // ── Status drawer state ───────────────────────────────────────────────────
  Esp32Status esp32Status = Esp32Status.empty;
  int    pingCount      = 0;
  String lastPingTime   = "—";
  String lastPrediction = "—";
  double lastConfidence = 0;
  int    totalAnomalies = 0;
  int    totalAlerts    = 0;
  int    bufferFill     = 0;

  // ── ML ─────────────────────────────────────────────────────────────────────
  final MLClassifier           classifier  = MLClassifier();
  final List<List<double>> sensorBuffer = [];
  bool  isProcessing = false;

  // ✅ FIX: hard cap at 50 — buffer never exceeds this
  static const int maxBufferSize = 50;

  @override
  void initState() {
    super.initState();
    loadUserData();
    classifier.init();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      driverName    = prefs.getString("name")    ?? LanguageHelper.t("unknown_driver");
      vehicleNumber = prefs.getString("vehicle") ?? LanguageHelper.t("not_set");
    });
  }

  // ── SCAN ──────────────────────────────────────────────────────────────────
  Future<void> startScan() async {
    if (isScanning) return;
    setState(() { isScanning = true; bleStatus = "Scanning..."; });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.platformName == "A4SafePulse") {
          await FlutterBluePlus.stopScan();
          await connectToDevice(r.device);
          break;
        }
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && !isConnected && mounted) {
        setState(() {
          isScanning = false;
          bleStatus  = "Device not found. Try again.";
        });
      }
    });
  }

  // ── CONNECT ───────────────────────────────────────────────────────────────
  Future<void> connectToDevice(BluetoothDevice device) async {
    setState(() { bleStatus = "Connecting..."; });
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        connectedDevice = device;
        isConnected     = true;
        isScanning      = false;
        bleStatus       = "Connected to A4SafePulse ✅";
      });

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            isConnected  = false;
            bleStatus    = "Disconnected ❌";
            dataChar     = null;
            statusChar   = null;
            esp32Status  = Esp32Status.empty;
          });
        }
      });

      await discoverServices(device);
    } catch (e) {
      if (!mounted) return;
      setState(() { bleStatus = "Connection failed: $e"; isScanning = false; });
    }
  }

  // ── DISCOVER SERVICES ─────────────────────────────────────────────────────
  Future<void> discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() != SERVICE_UUID.toLowerCase()) continue;

      for (final c in service.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();

        if (uuid == CHAR_DATA_UUID.toLowerCase()) {
          dataChar = c;
          await c.setNotifyValue(true);
          c.onValueReceived.listen((value) {
            handleIncomingData(String.fromCharCodes(value));
          });
          debugPrint("✅ Data characteristic subscribed");
        }

        if (uuid == CHAR_STATUS_UUID.toLowerCase()) {
          statusChar = c;
          await c.setNotifyValue(true);
          c.onValueReceived.listen((value) {
            final raw = String.fromCharCodes(value);
            if (raw.startsWith("STATUS:") && mounted) {
              setState(() { esp32Status = Esp32Status.fromString(raw); });
            }
          });
          try {
            final val = await c.read();
            final raw = String.fromCharCodes(val);
            if (raw.startsWith("STATUS:") && mounted) {
              setState(() { esp32Status = Esp32Status.fromString(raw); });
            }
          } catch (_) {}
          debugPrint("✅ Status characteristic subscribed");
        }
      }
    }
  }

  // ── HANDLE INCOMING DATA ──────────────────────────────────────────────────
  void handleIncomingData(String data) {
    if (!monitoring) return;
    data = data.trim();

    // PING heartbeat
    if (data.startsWith("PING:")) {
      final score = double.tryParse(data.substring(5)) ?? 0;
      if (mounted) {
        setState(() {
          pingCount++;
          lastPingTime = _nowTime();
          esp32Status  = Esp32Status(
            state: 'MONITORING', mpuOk: true,
            compositeScore: score, anomalyActive: false,
            samplesInFlight: 0, lastSeen: DateTime.now(),
          );
        });
      }
      return;
    }

    // ANOMALY trigger
    if (data.startsWith("ANOMALY:")) {
      if (isProcessing) return;
      sensorBuffer.clear();
      totalAnomalies++;
      if (mounted) setState(() { bufferFill = 0; });
      debugPrint("⚡ ANOMALY triggered — collecting samples...");
      return;
    }

    // END → run ML
    if (data == "END") {
      if (sensorBuffer.length >= 10) {
        debugPrint("Buffer complete — ${sensorBuffer.length} readings → ML");
        runMLPrediction();
      } else {
        debugPrint("Buffer too small (${sensorBuffer.length}), ignoring");
        sensorBuffer.clear();
      }
      if (mounted) setState(() { bufferFill = 0; });
      return;
    }

    // Sensor data line: "ax,ay,az,gx,gy,gz"
    if (isProcessing) return;

    // ✅ FIX: hard cap — never exceed 50 samples
    if (sensorBuffer.length >= maxBufferSize) return;

    try {
      final parts = data.split(",");
      if (parts.length == 6) {
        sensorBuffer.add(parts.map(double.parse).toList());
        if (mounted) setState(() { bufferFill = sensorBuffer.length; });
      }
    } catch (e) {
      debugPrint("Parse error: $e — raw: $data");
    }
  }

  // ── FEATURE EXTRACTION ────────────────────────────────────────────────────
  Map<String, double> extractFeatures(List<List<double>> buffer) {
    final accMag  = <double>[];
    final gyroMag = <double>[];

    for (final r in buffer) {
      final ax = r[0], ay = r[1], az = r[2];
      final gx = r[3], gy = r[4], gz = r[5];
      accMag.add(sqrt(ax*ax + ay*ay + az*az));
      gyroMag.add(sqrt(gx*gx + gy*gy + gz*gz));
    }

    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    double std(List<double> v) {
      final m = mean(v);
      return sqrt(v.map((x) => (x-m)*(x-m)).reduce((a,b) => a+b) / v.length);
    }
    double energy(List<double> v) => v.map((x) => x*x).reduce((a,b) => a+b);

    final jerk = <double>[];
    for (int i = 1; i < accMag.length; i++) {
      jerk.add((accMag[i] - accMag[i-1]).abs());
    }

    return {
      'peak_acc':    accMag.reduce(max),
      'mean_acc':    mean(accMag),
      'std_acc':     std(accMag),
      'acc_range':   accMag.reduce(max) - accMag.reduce(min),
      'jerk_mean':   jerk.isEmpty ? 0.0 : mean(jerk),
      'gyro_mean':   mean(gyroMag),
      'gyro_std':    std(gyroMag),
      'gyro_range':  gyroMag.reduce(max) - gyroMag.reduce(min),
      'energy_acc':  energy(accMag),
      'energy_gyro': energy(gyroMag),
    };
  }

  // ── ML PREDICTION ─────────────────────────────────────────────────────────
  Future<void> runMLPrediction() async {
    if (sensorBuffer.isEmpty) return;
    isProcessing = true;

    try {
      final features = extractFeatures(List.from(sensorBuffer));
      debugPrint("Features: $features");

      final result = await classifier.predictWithConfidence(
        peakAcc:    features['peak_acc']!,
        meanAcc:    features['mean_acc']!,
        stdAcc:     features['std_acc']!,
        accRange:   features['acc_range']!,
        jerkMean:   features['jerk_mean']!,
        gyroMean:   features['gyro_mean']!,
        gyroStd:    features['gyro_std']!,
        gyroRange:  features['gyro_range']!,
        energyAcc:  features['energy_acc']!,
        energyGyro: features['energy_gyro']!,
      );

      debugPrint("ML Result: $result");

      if (mounted) {
        setState(() {
          lastPrediction = result.isAccidentClass
              ? "🚨 Accident (class ${result.predictedClass})"
              : "✅ No accident (class ${result.predictedClass})";
          lastConfidence = result.accidentConfidence;
        });
      }

      if (result.isIgnored) {
        debugPrint("Confidence ${result.accidentConfidence.toStringAsFixed(2)} "
            "below threshold — ignored");
      } else if (!result.isAccidentClass) {
        debugPrint("Class ${result.predictedClass} = normal — no alert");
      } else if (mounted) {
        totalAlerts++;
        setState(() {});
        debugPrint("🚨 ACCIDENT! Class: ${result.predictedClass}, "
            "Confidence: ${result.accidentConfidence.toStringAsFixed(2)}");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlertScreen(
              isHighPriority: result.isHighPriorityAlert,
              accidentClass:  result.predictedClass,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("ML Error: $e");
      if (mounted) setState(() { lastPrediction = "ML Error: $e"; });
    } finally {
      sensorBuffer.clear();
      isProcessing = false;
    }
  }

  // ── DISCONNECT ────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    if (!mounted) return;
    setState(() {
      isConnected     = false;
      bleStatus       = "Disconnected";
      connectedDevice = null;
      dataChar        = null;
      statusChar      = null;
      esp32Status     = Esp32Status.empty;
    });
  }

  String _nowTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2,'0')}:"
        "${now.minute.toString().padLeft(2,'0')}:"
        "${now.second.toString().padLeft(2,'0')}";
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    classifier.dispose();
    super.dispose();
  }

  // ── STATUS DRAWER ─────────────────────────────────────────────────────────
  Widget _buildStatusDrawer() {
    final bool alive = isConnected &&
        esp32Status.lastSeen.millisecondsSinceEpoch > 0 &&
        DateTime.now().difference(esp32Status.lastSeen).inSeconds < 10;

    Color stateColor(String s) {
      if (s.contains('ANOMALY'))    return Colors.red;
      if (s.contains('CAPTURING'))  return Colors.orange;
      if (s.contains('MONITORING')) return Colors.green;
      return Colors.grey;
    }

    // ✅ FIX: Flexible on value side — prevents 334px overflow
    Widget statusRow(IconData icon, String label, String value, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget sectionHeader(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(title,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: Colors.black38, letterSpacing: 1.2,
        ),
      ),
    );

    Widget scoreBar(double score) {
      final color = score > 0.5 ? Colors.red
          : score > 0.3 ? Colors.orange
          : Colors.green;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Sensor score",
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              Text(score.toStringAsFixed(3),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      );
    }

    Widget bufferBar(int fill) {
      final pct = (fill / 50.0).clamp(0.0, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Buffer fill",
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              Text("$fill / 50",
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 8,
            ),
          ),
        ],
      );
    }

    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.monitor_heart, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("System Status",
                        style: TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    alive ? "Live data — updated ${_nowTime()}" : "No data",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    sectionHeader("BLE CONNECTION"),
                    statusRow(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      "Status",
                      isConnected ? "Connected" : "Disconnected",
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    if (isConnected)
                      statusRow(Icons.devices, "Device", "A4SafePulse"),
                    statusRow(
                      Icons.sensors, "Data pipeline",
                      alive ? "Active" : "No signal",
                      color: alive ? Colors.green : Colors.orange,
                    ),
                    statusRow(Icons.favorite, "Heartbeats", "$pingCount pings"),
                    if (lastPingTime != "—")
                      statusRow(Icons.access_time, "Last ping", lastPingTime),

                    const Divider(height: 24),

                    sectionHeader("ESP32 SENSOR"),
                    statusRow(
                      esp32Status.mpuOk ? Icons.check_circle : Icons.error_outline,
                      "MPU6050",
                      esp32Status.mpuOk ? "OK" : "FAILED",
                      color: esp32Status.mpuOk ? Colors.green : Colors.red,
                    ),
                    statusRow(
                      Icons.radio_button_checked, "State",
                      esp32Status.state,
                      color: stateColor(esp32Status.state),
                    ),
                    const SizedBox(height: 12),
                    scoreBar(esp32Status.compositeScore),

                    const Divider(height: 24),

                    sectionHeader("DATA PIPELINE"),
                    if (isProcessing) ...[
                      const Row(children: [
                        SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text("Running ML model...",
                            style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      ]),
                      const SizedBox(height: 8),
                    ],
                    bufferBar(bufferFill),
                    const SizedBox(height: 12),
                    statusRow(
                      Icons.bolt, "Anomalies detected", "$totalAnomalies",
                      color: totalAnomalies > 0 ? Colors.orange : Colors.grey,
                    ),

                    const Divider(height: 24),

                    sectionHeader("ML RESULTS"),
                    statusRow(Icons.psychology, "Last prediction", lastPrediction),
                    if (lastConfidence > 0)
                      statusRow(
                        Icons.percent, "Confidence",
                        "${(lastConfidence * 100).toStringAsFixed(1)}%",
                        color: lastConfidence > 0.8 ? Colors.red
                            : lastConfidence > 0.5 ? Colors.orange
                            : Colors.green,
                      ),
                    statusRow(
                      Icons.warning_amber, "Alerts sent", "$totalAlerts",
                      color: totalAlerts > 0 ? Colors.red : Colors.grey,
                    ),

                    const Divider(height: 24),

                    sectionHeader("ML MODEL"),
                    statusRow(Icons.model_training, "Model", "Random Forest"),
                    statusRow(Icons.layers, "Classes", "0–5 (acc/accident)"),
                    statusRow(Icons.tune, "Lower threshold",
                        "${(MLResult.lowerThreshold * 100).toStringAsFixed(0)}%"),
                    statusRow(Icons.tune, "Upper threshold",
                        "${(MLResult.upperThreshold * 100).toStringAsFixed(0)}%"),

                    const SizedBox(height: 20),

                    if (!isConnected)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Icon(Icons.warning, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text("Connect to ESP32 to start monitoring.",
                                style: TextStyle(fontSize: 12)),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MAIN BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffde6e6),
      endDrawer: _buildStatusDrawer(),

      appBar: AppBar(
        title: const Text("A4 Safe Pulse"),
        backgroundColor: Colors.redAccent,
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Stack(children: [
                const Icon(Icons.monitor_heart),
                if (isConnected)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: esp32Status.state.contains('ANOMALY')
                            ? Colors.red : Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ]),
              tooltip: "System status",
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingScreen()));
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

            // Driver card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${LanguageHelper.t("driver")}: $driverName",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.directions_car, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${LanguageHelper.t("vehicle")}: $vehicleNumber",
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // BLE card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bleStatus,
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: isConnected ? Colors.green : Colors.red,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    if (isConnected && pingCount > 0) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            const Icon(Icons.sensors, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text("Live · ${esp32Status.state}",
                                style: const TextStyle(fontSize: 11, color: Colors.green)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Text("Score: ${esp32Status.compositeScore.toStringAsFixed(3)}",
                            style: const TextStyle(fontSize: 11, color: Colors.black45)),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected ? Colors.grey : Colors.blue,
                        ),
                        icon: Icon(isConnected ? Icons.bluetooth_disabled : Icons.bluetooth),
                        label: Text(isConnected ? "Disconnect"
                            : (isScanning ? "Scanning..." : "Connect to ESP32")),
                        onPressed: isScanning ? null
                            : (isConnected ? disconnect : startScan),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Monitoring toggle
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        LanguageHelper.t("monitoring_status"),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Switch(
                      value: monitoring,
                      activeColor: Colors.green,
                      onChanged: (v) => setState(() { monitoring = v; }),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            Text(LanguageHelper.t("emergency_numbers"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                icon: const Icon(Icons.warning),
                label: Text(LanguageHelper.t("send_alert"),
                    style: const TextStyle(fontSize: 16)),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AlertScreen())),
              ),
            ),

          ],
        ),
      ),
    );
  }
}