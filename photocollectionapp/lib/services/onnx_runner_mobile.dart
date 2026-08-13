import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../utils/logger.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'onnx_types.dart';

const int modelWidth = 1280;
const int modelHeight = 1280;

class OnnxRunner implements OnnxRunnerBase {
  late Isolate _isolate;
  late SendPort _sendPort;

  @override
  Future<void> start(String modelAsset) async {
    final raw = await rootBundle.load(modelAsset);
    final modelBytes = raw.buffer.asUint8List();

    // Write the model bytes to a temporary file and pass the path to the isolate.
    final tmp = Directory.systemTemp;
    final modelFile = await File('${tmp.path}/onnx_model_${DateTime.now().microsecondsSinceEpoch}.onnx').create();
    await modelFile.writeAsBytes(modelBytes, flush: true);
    final modelPath = modelFile.path;

    final readyPort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();

    errorPort.listen((e) {
      logger.e("ISOLATE ERROR: $e");
    });

    exitPort.listen((_) {
      logger.i("ISOLATE EXITED");
    });

    _isolate = await Isolate.spawn(
      _isolateEntry,
      [readyPort.sendPort, modelPath],
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );

    _sendPort = await readyPort.first as SendPort;
  }

  @override
  Future<DetectionResult> detect(Uint8List bytes) async {
    final response = ReceivePort();

    _sendPort.send([bytes, response.sendPort]);
    logger.i("Isolate runner waiting for result.");

    final result = await response.first;
    logger.i("Isolate runner recieved:$result");

    return (result as DetectionResult);
  }

  static Future<void> _isolateEntry(List args) async {
    try {
      final SendPort mainSendPort = args[0];
      final String modelPath = args[1];

      logger.i("ISOLATE STARTED");

      final port = ReceivePort();
      mainSendPort.send(port.sendPort);

      logger.i("INIT ONNX");

      // Read model bytes from the temporary file inside the isolate.
      final modelFile = File(modelPath);
      final modelBytes = await modelFile.readAsBytes();

      logger.i("Model bytes length: ${modelBytes.length}");
      logger.i("Model header: ${modelBytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");

      OrtEnv.instance.init();
      // Quick heuristic: if the model bytes contain the ascii string "pytorch",
      // it's likely not a valid ONNX protobuf (common when a PyTorch checkpoint
      // or wrong file was bundled). Log and provide actionable guidance.
      final headerSnippet = String.fromCharCodes(modelBytes.take(128));
      if (headerSnippet.contains('pytorch')) {
        logger.e('Model file appears to contain PyTorch data (contains "pytorch").');
        logger.e('This is not a valid ONNX protobuf. Re-export the model to ONNX and ensure the file is a plain .onnx protobuf.');
      }

      late final OrtSession session;
      try {
        session = OrtSession.fromBuffer(modelBytes, OrtSessionOptions());
      } catch (e) {
        logger.e("OrtSession.fromBuffer failed: $e");
        logger.e('Failed to parse ONNX model bytes. Possible causes: corrupted asset, wrong file (PyTorch checkpoint), or unsupported/unknown opset.');
        logger.e('Remediation: validate the model with `onnx.checker.check_model` and re-export using `torch.onnx.export` or an ONNX-compatible exporter.');
        rethrow;
      }

      logger.i("SESSION CREATED");

      await for (final message in port) {
        logger.i("MESSAGE RECEIVED");

        final Uint8List imageBytes = message[0];
        final SendPort replyPort = message[1];

        logger.i("RUNNING INFERENCE");

        final image = img.decodeImage(imageBytes)!;
        
        logger.i("Resizing");
        final resized = img.copyResize(
          image,
          width: modelWidth,
          height: modelHeight,
        );

        final scaleX = image.width / modelWidth;
        final scaleY = image.height / modelHeight;

        logger.i("Converting image to Indexed Uint8 list");
        final rgbaUints = resized.toUint8List();
        final indexed = rgbaUints.indexed;

        logger.i("RGB->BGR");
        final rgbFloats = [
          ...indexed
              .where((e) => e.$1 % 3 == 2)
              .map((e) => e.$2.toDouble()), // Blue
          ...indexed
              .where((e) => e.$1 % 3 == 1)
              .map((e) => e.$2.toDouble()), // Green
          ...indexed
              .where((e) => e.$1 % 3 == 0)
              .map((e) => e.$2.toDouble()), // Red
        ];

        final inputOrt = OrtValueTensor.createTensorWithDataList(
          Float32List.fromList(rgbFloats),
          [3, modelHeight, modelWidth],
        );

        final outputs = session.run(OrtRunOptions(), {'image': inputOrt});

        // Clean up
        inputOrt.release();

        final l = (outputs[0]!.value as List).length;

        logger.i("runtimeType: ${outputs[0]!.value.runtimeType} length: $l");

        List boxes = outputs[0]?.value as List;

        boxes =
            boxes.map((b) {
              return [
                b[0] * scaleX,
                b[1] * scaleY,
                b[2] * scaleX,
                b[3] * scaleY,
              ];
            }).toList();

        List classes = outputs[1]?.value as List;
        List scores = outputs[2]?.value as List;

        final result = DetectionResult(
          boxes: boxes.map<List<double>>((e) => List<double>.from(e)).toList(),
          scores: List<double>.from(scores),
          classes: List<int>.from(classes),
        );

        logger.i("SENDING RESULT");
        replyPort.send(result);
      }
    } catch (e, s) {
      logger.e("ISOLATE CRASH: $e");
      logger.e(s);
    }
  }
}