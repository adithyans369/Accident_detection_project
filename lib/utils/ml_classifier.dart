import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class MLClassifier {
  OrtSession? _session;

  Future<void> init() async {
    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final rawAssetFile =
    await rootBundle.load('assets/rf_accident_model_fixed-2.onnx');
    final bytes = rawAssetFile.buffer.asUint8List();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
    print("✅ ML Model loaded successfully");
  }

  /// Returns the predicted class label from 0 to 5.
  Future<int> predict({
    required double peakAcc,
    required double meanAcc,
    required double stdAcc,
    required double accRange,
    required double jerkMean,
    required double gyroMean,
    required double gyroStd,
    required double gyroRange,
    required double energyAcc,
    required double energyGyro,
  }) async {
    if (_session == null) await init();

    final inputData = Float32List.fromList([
      peakAcc, meanAcc, stdAcc, accRange, jerkMean,
      gyroMean, gyroStd, gyroRange, energyAcc, energyGyro,
    ]);

    final inputTensor =
    OrtValueTensor.createTensorWithDataList(inputData, [1, 10]);
    final outputs =
    await _session!.runAsync(OrtRunOptions(), {'float_input': inputTensor});

    final output = outputs?[0]?.value as List<dynamic>;
    final prediction = (output[0] as num).toInt();

    inputTensor.release();
    outputs?.forEach((e) => e?.release());

    return prediction;
  }

  /// Returns the predicted class and accident confidence.
  Future<MLResult> predictWithConfidence({
    required double peakAcc,
    required double meanAcc,
    required double stdAcc,
    required double accRange,
    required double jerkMean,
    required double gyroMean,
    required double gyroStd,
    required double gyroRange,
    required double energyAcc,
    required double energyGyro,
  }) async {
    if (_session == null) await init();

    final inputData = Float32List.fromList([
      peakAcc, meanAcc, stdAcc, accRange, jerkMean,
      gyroMean, gyroStd, gyroRange, energyAcc, energyGyro,
    ]);

    final inputTensor =
    OrtValueTensor.createTensorWithDataList(inputData, [1, 10]);
    final outputs =
    await _session!.runAsync(OrtRunOptions(), {'float_input': inputTensor});

    // First output is the predicted class label.
    // ONNX may return the value as int64, so convert it safely.
    final labelOutput = outputs?[0]?.value as List<dynamic>;
    final predictedClass = (labelOutput[0] as num).toInt();

    double accidentConfidence = 0.0;

    if (outputs != null && outputs.length > 1) {
      final probOutput = outputs[1]?.value;
      if (probOutput != null) {
        try {
          // Second output is a probability list.
          // Index 0 to 5 matches class 0 to 5.
          final outerList = probOutput as List<dynamic>;
          final probList  = outerList[0] as List<dynamic>;

          double p3 = probList.length > 3 ? (probList[3] as num).toDouble() : 0.0;
          double p4 = probList.length > 4 ? (probList[4] as num).toDouble() : 0.0;
          double p5 = probList.length > 5 ? (probList[5] as num).toDouble() : 0.0;
          accidentConfidence = p3 + p4 + p5;

          print("📊 p3:${p3.toStringAsFixed(3)} "
              "p4:${p4.toStringAsFixed(3)} "
              "p5:${p5.toStringAsFixed(3)} "
              "total:${accidentConfidence.toStringAsFixed(3)}");
        } catch (e) {
          print("⚠️ Prob parse error: $e — using label fallback");
          accidentConfidence = _confidenceFromClass(predictedClass);
        }
      } else {
        accidentConfidence = _confidenceFromClass(predictedClass);
      }
    } else {
      // Use label-based confidence if probabilities are not available.
      accidentConfidence = _confidenceFromClass(predictedClass);
    }

    inputTensor.release();
    outputs?.forEach((e) => e?.release());

    print("🤖 ML → class: $predictedClass, "
        "confidence: ${accidentConfidence.toStringAsFixed(3)}");

    return MLResult(
      predictedClass: predictedClass,
      accidentConfidence: accidentConfidence,
    );
  }

  /// Gives a simple confidence value when probabilities are unavailable.
  double _confidenceFromClass(int cls) {
    return switch (cls) {
      3 => 0.65,
      4 => 0.85,
      5 => 1.0,
      _ => 0.0,
    };
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}

class MLResult {
  final int predictedClass;
  final double accidentConfidence; // Value from 0.0 to 1.0.

  // Thresholds used to decide alert priority.
  static const double lowerThreshold = 0.25;
  static const double upperThreshold = 0.50;

  bool get isIgnored       => accidentConfidence < lowerThreshold;
  bool get isNormalAlert   => accidentConfidence >= lowerThreshold &&
      accidentConfidence < upperThreshold;
  bool get isHighPriorityAlert => accidentConfidence >= upperThreshold;

  // Classes 3, 4, and 5 are accident classes.
  bool get isAccidentClass => predictedClass >= 3;

  MLResult({
    required this.predictedClass,
    required this.accidentConfidence,
  });

  @override
  String toString() =>
      'MLResult(class: $predictedClass, '
          'confidence: ${accidentConfidence.toStringAsFixed(2)})';
}
