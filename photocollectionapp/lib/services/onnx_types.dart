import 'dart:typed_data';

class DetectionResult {
  final List<List<double>> boxes;
  final List<double> scores;
  final List<int> classes;

  DetectionResult({
    required this.boxes,
    required this.scores,
    required this.classes,
  });
}

abstract class OnnxRunnerBase {
  Future<void> start(String modelAsset);
  Future<DetectionResult> detect(Uint8List bytes);
}