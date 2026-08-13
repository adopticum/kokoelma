import 'dart:typed_data';
import 'onnx_types.dart';

class OnnxRunner implements OnnxRunnerBase {
  @override
  Future<void> start(String modelAsset) async {
    // Stub for web implementation
  }

  @override
  Future<DetectionResult> detect(Uint8List bytes) async {
    // Stub for web implementation returning empty results
    return DetectionResult(
      boxes: [],
      scores: [],
      classes: [],
    );
  }
}
