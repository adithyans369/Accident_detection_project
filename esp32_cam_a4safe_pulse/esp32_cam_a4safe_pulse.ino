#include <Wire.h>
#include <MPU6050.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <math.h>

#define DEVICE_NAME "A4SafePulse"
#define SERVICE_UUID "12345678-1234-1234-1234-123456789012"
#define CHARACTERISTIC_UUID "87654321-4321-4321-4321-210987654321"

#define SDA_PIN 15
#define SCL_PIN 14

#define SAMPLE_DELAY_MS 100
#define FEATURE_WINDOW_SIZE 20
#define POST_ANOMALY_SAMPLES 50
#define COOLDOWN_MS 3000

// Keep true for Arduino Serial Plotter. Set false for readable Serial Monitor logs.
const bool serialPlotterMode = true;

// MPU6050 full-scale spectrum after configuration below:
// accel magnitude: 0g to 16g, gyro magnitude: 0dps to 2000dps.
// Lower 50% => Normal. Upper 50% => Anomaly.
const float anomalyThreshold = 0.50;

MPU6050 mpu;
BLECharacteristic *sensorCharacteristic;

bool deviceConnected = false;

void logMessage(const char *message);

struct SensorData {
  float ax, ay, az;
  float gx, gy, gz;
};

struct FeatureData {
  float peakAcc;
  float meanAcc;
  float jerkMean;
  float gyroMean;
};

SensorData featureWindow[FEATURE_WINDOW_SIZE];
int windowIndex = 0;
int windowCount = 0;

bool capturingAfterAnomaly = false;
int postSampleCount = 0;
unsigned long lastTriggerTime = 0;

FeatureData lastFeatures = {0, 0, 0, 0};
bool lastAnomaly = false;
float lastSpectrumScore = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) {
    deviceConnected = true;
    logMessage("Flutter app connected");
  }

  void onDisconnect(BLEServer *server) {
    deviceConnected = false;
    logMessage("Flutter app disconnected");
    BLEDevice::startAdvertising();
  }
};

void logMessage(const char *message) {
  if (!serialPlotterMode) {
    Serial.println(message);
  }
}

float accMagnitude(const SensorData &sample) {
  return sqrt(
    (sample.ax * sample.ax) +
    (sample.ay * sample.ay) +
    (sample.az * sample.az)
  );
}

float gyroMagnitude(const SensorData &sample) {
  return sqrt(
    (sample.gx * sample.gx) +
    (sample.gy * sample.gy) +
    (sample.gz * sample.gz)
  );
}

SensorData readSensor() {
  int16_t rawAx, rawAy, rawAz;
  int16_t rawGx, rawGy, rawGz;

  mpu.getMotion6(&rawAx, &rawAy, &rawAz, &rawGx, &rawGy, &rawGz);

  SensorData sample;

  // MPU6050 +/-16g range => 2048 LSB/g.
  sample.ax = rawAx / 2048.0;
  sample.ay = rawAy / 2048.0;
  sample.az = rawAz / 2048.0;

  // MPU6050 +/-2000 deg/s range => 16.4 LSB/(deg/s).
  sample.gx = rawGx / 16.4;
  sample.gy = rawGy / 16.4;
  sample.gz = rawGz / 16.4;

  return sample;
}

void updateFeatureWindow(const SensorData &sample) {
  featureWindow[windowIndex] = sample;
  windowIndex = (windowIndex + 1) % FEATURE_WINDOW_SIZE;

  if (windowCount < FEATURE_WINDOW_SIZE) {
    windowCount++;
  }
}

FeatureData calculateFeatures() {
  FeatureData features = {0, 0, 0, 0};

  if (windowCount < FEATURE_WINDOW_SIZE) {
    return features;
  }

  float accSum = 0;
  float gyroSum = 0;
  float jerkSum = 0;
  float previousAcc = accMagnitude(featureWindow[0]);

  for (int i = 0; i < FEATURE_WINDOW_SIZE; i++) {
    float acc = accMagnitude(featureWindow[i]);
    float gyro = gyroMagnitude(featureWindow[i]);

    if (acc > features.peakAcc) {
      features.peakAcc = acc;
    }

    accSum += acc;
    gyroSum += gyro;

    if (i > 0) {
      jerkSum += fabs(acc - previousAcc);
    }

    previousAcc = acc;
  }

  features.meanAcc = accSum / FEATURE_WINDOW_SIZE;
  features.gyroMean = gyroSum / FEATURE_WINDOW_SIZE;
  features.jerkMean = jerkSum / (FEATURE_WINDOW_SIZE - 1);

  return features;
}

float sensorSpectrumScore(const SensorData &sample) {
  float accScore = accMagnitude(sample) / 16.0;
  float gyroScore = gyroMagnitude(sample) / 2000.0;
  float score = max(accScore, gyroScore);

  if (score < 0) return 0;
  if (score > 1) return 1;
  return score;
}

bool anomalyDetectedFromSpectrum(const SensorData &sample) {
  lastSpectrumScore = sensorSpectrumScore(sample);
  return lastSpectrumScore >= anomalyThreshold;
}

void sendLineToFlutter(const String &line) {
  if (!deviceConnected) {
    return;
  }

  sensorCharacteristic->setValue(line.c_str());
  sensorCharacteristic->notify();

  delay(30);
}

void sendSensorDataToFlutter(const SensorData &sample) {
  String data =
    String(sample.ax, 3) + "," +
    String(sample.ay, 3) + "," +
    String(sample.az, 3) + "," +
    String(sample.gx, 3) + "," +
    String(sample.gy, 3) + "," +
    String(sample.gz, 3);

  sendLineToFlutter(data);

  if (!serialPlotterMode) {
    Serial.println(data);
  }
}

void printSerialPlotterLine(
  const SensorData &sample,
  float accMag,
  float gyroMag,
  const FeatureData &features,
  bool anomaly
) {
  if (!serialPlotterMode) {
    Serial.print("AX: ");
    Serial.print(sample.ax, 3);
    Serial.print(" AY: ");
    Serial.print(sample.ay, 3);
    Serial.print(" AZ: ");
    Serial.print(sample.az, 3);
    Serial.print(" | AccMag: ");
    Serial.print(accMag, 3);
    Serial.print(" | PeakAcc: ");
    Serial.print(features.peakAcc, 3);
    Serial.print(" | GyroMean: ");
    Serial.print(features.gyroMean, 3);
    Serial.print(" | JerkMean: ");
    Serial.print(features.jerkMean, 3);
    Serial.print(" | Anomaly: ");
    Serial.print(anomaly ? 1 : 0);
    Serial.print(" | BLE: ");
    Serial.println(deviceConnected ? 1 : 0);
    return;
  }

  Serial.print("accMag:");
  Serial.print(accMag, 3);
  Serial.print("\tgyroMag:");
  Serial.print(gyroMag, 3);
  Serial.print("\tpeakAcc:");
  Serial.print(features.peakAcc, 3);
  Serial.print("\tmeanAcc:");
  Serial.print(features.meanAcc, 3);
  Serial.print("\tjerkMean:");
  Serial.print(features.jerkMean, 3);
  Serial.print("\tgyroMean:");
  Serial.print(features.gyroMean, 3);
  Serial.print("\tspectrumScore:");
  Serial.print(lastSpectrumScore, 3);
  Serial.print("\tanomaly:");
  Serial.print(anomaly ? 12 : 0);
  Serial.print("\tcapturing:");
  Serial.print(capturingAfterAnomaly ? 10 : 0);
  Serial.print("\tsentCount:");
  Serial.print(postSampleCount);
  Serial.print("\tble:");
  Serial.println(deviceConnected ? 8 : 0);
}

void setupBle() {
  BLEDevice::init(DEVICE_NAME);
  BLEDevice::setMTU(185);

  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  sensorCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );

  sensorCharacteristic->addDescriptor(new BLE2902());

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();

  logMessage("BLE started. Device name: A4SafePulse");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Wire.begin(SDA_PIN, SCL_PIN);

  logMessage("Initializing MPU6050...");
  mpu.initialize();

  if (mpu.testConnection()) {
    logMessage("MPU6050 connected successfully");
  } else {
    logMessage("MPU6050 connection failed");
  }

  mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_16);
  mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_2000);

  setupBle();
}

void loop() {
  SensorData sample = readSensor();
  updateFeatureWindow(sample);

  float accMag = accMagnitude(sample);
  float gyroMag = gyroMagnitude(sample);

  lastFeatures = calculateFeatures();

  bool cooldownFinished = millis() - lastTriggerTime > COOLDOWN_MS;
  lastAnomaly =
    !capturingAfterAnomaly &&
    cooldownFinished &&
    anomalyDetectedFromSpectrum(sample);

  if (lastAnomaly) {
    logMessage("ANOMALY DETECTED. Capturing next 50 samples...");
    sendLineToFlutter("ANOMALY");
    capturingAfterAnomaly = true;
    postSampleCount = 0;
    lastTriggerTime = millis();
  }

  if (capturingAfterAnomaly) {
    sendSensorDataToFlutter(sample);
    postSampleCount++;

    if (postSampleCount >= POST_ANOMALY_SAMPLES) {
      sendLineToFlutter("END");
      logMessage("END sent to Flutter");

      capturingAfterAnomaly = false;
      postSampleCount = 0;
      lastTriggerTime = millis();
    }
  }

  printSerialPlotterLine(sample, accMag, gyroMag, lastFeatures, lastAnomaly);

  delay(SAMPLE_DELAY_MS);
}
