// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'package:flutter/painting.dart';
// import 'dart:io';

// import 'package:flutter/services.dart';
// import 'package:onnxruntime/onnxruntime.dart';

// class DetectionResult {
//   final List<List<double>> boxes;
//   final List<double> scores;
//   final List<int> classes;

//   DetectionResult({
//     required this.boxes,
//     required this.scores,
//     required this.classes,
//   });
// }

// class OnnxService {
//   OrtSession? _session;
//   bool _initialized = false;

//   /// Initialize once (call from app startup or first usage)
//   Future<void> init(String modelAssetPath) async {
//     if (_initialized) return;

//     OrtEnv.instance.init();

//     final sessionOptions = OrtSessionOptions();
//     final raw = await rootBundle.load(modelAssetPath);
//     final bytes = raw.buffer.asUint8List();

//     _session = OrtSession.fromBuffer(bytes, sessionOptions);
//     _initialized = true;
//   }

//   /// Run detection on image file
//   Future<DetectionResult> runDetection(File imageFile) async {
//     if (_session == null) {
//       throw Exception("OnnxService not initialized");
//     }

//     final bytes = await imageFile.readAsBytes();
//     final image = await decodeImageFromList(bytes);

//     final inputTensor = await _imageToTensor(image);

//     final inputOrt = OrtValueTensor.createTensorWithDataList(
//       Float32List.fromList(inputTensor),
//       [3, image.height, image.width],
//     );

//     final runOptions = OrtRunOptions();

//     final outputs = _session!.run(
//       runOptions,
//       {'image': inputOrt},
//     );

//     inputOrt.release();
//     runOptions.release();

//     List boxes = outputs[0]?.value as List;
//     List classes = outputs[1]?.value as List;
//     List scores = outputs[2]?.value as List;

//     return DetectionResult(
//       boxes: boxes.map<List<double>>((e) => List<double>.from(e)).toList(),
//       scores: List<double>.from(scores),
//       classes: List<int>.from(classes),
//     );
//   }

//   Future<List<double>> _imageToTensor(ui.Image image) async {
//     final byteData =
//         await image.toByteData(format: ui.ImageByteFormat.rawRgba);
//     final rgba = Uint8List.view(byteData!.buffer);

//     final indexed = rgba.indexed;

//     // BGR layout (many ONNX detection models expect this)
//     return [
//       ...indexed.where((e) => e.$1 % 4 == 2).map((e) => e.$2.toDouble()), // B
//       ...indexed.where((e) => e.$1 % 4 == 1).map((e) => e.$2.toDouble()), // G
//       ...indexed.where((e) => e.$1 % 4 == 0).map((e) => e.$2.toDouble()), // R
//     ];
//   }

//   void dispose() {
//     _session?.release();
//     OrtEnv.instance.release();
//     _session = null;
//     _initialized = false;
//   }
// }
