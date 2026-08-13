import 'package:flutter/material.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<List<double>> boxes;
  final List<double> scores;
  final List<int> classes;
  final double imageWidth;
  final double imageHeight;

  BoundingBoxPainter(
    this.boxes,
    this.scores,
    this.classes,
    this.imageWidth,
    this.imageHeight,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rectPaint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    // how the image is fitted inside the widget
    final fittedSizes = applyBoxFit(
      BoxFit.contain,
      Size(imageWidth, imageHeight),
      size,
    );

    final renderSize = fittedSizes.destination;

    final dx = (size.width - renderSize.width) / 2;
    final dy = (size.height - renderSize.height) / 2;

    final scaleX = renderSize.width / imageWidth;
    final scaleY = renderSize.height / imageHeight;

    for (int i = 0; i < boxes.length; i++) {
      final b = boxes[i];

      final rect = Rect.fromLTRB(
        b[0] * scaleX + dx,
        b[1] * scaleY + dy,
        b[2] * scaleX + dx,
        b[3] * scaleY + dy,
      );

      canvas.drawRect(rect, rectPaint);

      final label = "C:${classes[i]} ${(scores[i] * 100).toStringAsFixed(1)}%";

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
