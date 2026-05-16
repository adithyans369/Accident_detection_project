import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class MLClassifier {
  OrtSession? _session;

  Future<void> init() async {
    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final rawAssetFile = await rootBundle.load('assets/rf_accident_model_fixed.onnx');
    final bytes = rawAssetFile.buffer.asUint8List();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
    print("✅ ML Model loaded successfully");
  }

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

    final shape = [1, 10];
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      shape,
    );

    final inputs = {'float_input': inputTensor};
    final outputs = await _session!.runAsync(OrtRunOptions(), inputs);

    final output = outputs?[0]?.value as List<dynamic>;
    final prediction = output[0] as int;

    inputTensor.release();
    outputs?.forEach((e) => e?.release());

    return prediction;
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}