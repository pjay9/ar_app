import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class PartOverlayPainter extends CustomPainter {
  final List<DetectedObject> detections;

  PartOverlayPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    for (var det in detections) {
      final rect = Rect.fromLTRB(
        det.left * size.width,
        det.top * size.height,
        det.right * size.width,
        det.bottom * size.height,
      );

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, boxPaint);

      // Label background
      final label = "${det.label} ${(det.confidence * 100).toStringAsFixed(0)}%";
      final textPainter = TextPainter(
        text: TextSpan(
          text: " $label ",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 2,
        textPainter.width,
        textPainter.height,
      );
      canvas.drawRect(labelRect, Paint()..color = Colors.greenAccent);
      textPainter.paint(canvas, Offset(rect.left, rect.top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}