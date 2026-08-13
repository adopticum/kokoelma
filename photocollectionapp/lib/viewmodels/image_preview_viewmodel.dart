import 'package:flutter/material.dart';
import '../services/onnx_runner.dart';
import '../models/photo_abstract.dart';
import '../models/photo_resolution.dart';

class ImagePreviewViewModel extends ChangeNotifier {
  final OnnxRunner runner = OnnxRunner();

  bool initialized = false;
  bool detected = false;
  bool _loading = false;
  bool get loading => _loading;

  DetectionResult detectionResults = DetectionResult(
    boxes: [],
    scores: [],
    classes: [],
  );

  Future<void> init() async {
    if (initialized) return;
    await runner.start("assets/onnx_models/log_ends.onnx");
    initialized = true;
  }

  void clearResults() {
    detectionResults = DetectionResult(boxes: [], scores: [], classes: []);
    detected = false;
    notifyListeners();
  }

  /* dep.
  Future<void> detect(Uint8List bytes) async {
    _loading = true;
    clearResults();

    await init();

    detectionResults = await runner.detect(bytes);

    final boxes =
        detectionResults.boxes
            .toList(); // just for printing, the view should use detectionResult.
    logger.i("Viewmodel recieved boxes: $boxes");
    _loading = false;
    detected = true;

    notifyListeners();
  }
  */

  Future<void> detectFromPhoto(Photo photo) async {
    _loading = true;
    clearResults();
    notifyListeners();

    await init();

    // Only place that loads bytes now
    final bytes = await photo.loadBytes(PhotoResolution.mini); //TODO: .full

    detectionResults = await runner.detect(bytes);

    _loading = false;
    detected = true;
    notifyListeners();
  }
}
