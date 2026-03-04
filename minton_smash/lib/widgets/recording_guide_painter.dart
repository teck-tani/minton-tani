import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter that draws a badminton player silhouette with phone position guides.
/// Shows correct (front/side) and incorrect (diagonal) recording angles.
class RecordingGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final playerY = size.height * 0.15;

    // Draw the badminton player silhouette (center)
    _drawPlayer(canvas, centerX, playerY, size.height * 0.65);

    // Draw phone positions
    final phoneY = size.height * 0.45;

    // Correct phone (front) - center
    _drawPhone(canvas, centerX, phoneY - 30, true);
    _drawLabel(canvas, '정면', centerX, phoneY + 30, Colors.green);

    // Incorrect phone (left diagonal)
    _drawPhone(canvas, centerX - size.width * 0.32, phoneY, false);
    _drawLabel(canvas, '대각', centerX - size.width * 0.32, phoneY + 50, Colors.red);

    // Incorrect phone (right diagonal)
    _drawPhone(canvas, centerX + size.width * 0.32, phoneY, false);
    _drawLabel(canvas, '대각', centerX + size.width * 0.32, phoneY + 50, Colors.red);
  }

  void _drawPlayer(Canvas canvas, double cx, double startY, double height) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.grey[400]!.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final scale = height / 180;

    // Head
    canvas.drawCircle(Offset(cx, startY + 15 * scale), 12 * scale, paint);
    canvas.drawCircle(Offset(cx, startY + 15 * scale), 12 * scale, fillPaint);

    // Neck
    canvas.drawLine(
      Offset(cx, startY + 27 * scale),
      Offset(cx, startY + 35 * scale),
      paint,
    );

    // Shoulders
    canvas.drawLine(
      Offset(cx - 25 * scale, startY + 40 * scale),
      Offset(cx + 25 * scale, startY + 40 * scale),
      paint,
    );

    // Torso
    canvas.drawLine(
      Offset(cx, startY + 35 * scale),
      Offset(cx, startY + 85 * scale),
      paint,
    );

    // Left arm (holding racket up)
    canvas.drawLine(
      Offset(cx - 25 * scale, startY + 40 * scale),
      Offset(cx - 30 * scale, startY + 60 * scale),
      paint,
    );
    // Left forearm going up with racket
    canvas.drawLine(
      Offset(cx - 30 * scale, startY + 60 * scale),
      Offset(cx - 15 * scale, startY + 25 * scale),
      paint,
    );

    // Racket
    final racketPaint = Paint()
      ..color = Colors.grey[500]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    // Racket handle
    canvas.drawLine(
      Offset(cx - 15 * scale, startY + 25 * scale),
      Offset(cx - 8 * scale, startY + 5 * scale),
      racketPaint,
    );
    // Racket head (oval)
    canvas.save();
    canvas.translate(cx - 5 * scale, startY - 8 * scale);
    canvas.rotate(-0.3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 18 * scale, height: 22 * scale),
      racketPaint,
    );
    canvas.restore();

    // Right arm (relaxed)
    canvas.drawLine(
      Offset(cx + 25 * scale, startY + 40 * scale),
      Offset(cx + 28 * scale, startY + 60 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(cx + 28 * scale, startY + 60 * scale),
      Offset(cx + 22 * scale, startY + 75 * scale),
      paint,
    );

    // Hips
    canvas.drawLine(
      Offset(cx - 18 * scale, startY + 85 * scale),
      Offset(cx + 18 * scale, startY + 85 * scale),
      paint,
    );

    // Left leg (slight lunge stance)
    canvas.drawLine(
      Offset(cx - 18 * scale, startY + 85 * scale),
      Offset(cx - 25 * scale, startY + 120 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(cx - 25 * scale, startY + 120 * scale),
      Offset(cx - 28 * scale, startY + 155 * scale),
      paint,
    );

    // Right leg
    canvas.drawLine(
      Offset(cx + 18 * scale, startY + 85 * scale),
      Offset(cx + 22 * scale, startY + 120 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(cx + 22 * scale, startY + 120 * scale),
      Offset(cx + 20 * scale, startY + 155 * scale),
      paint,
    );

    // Feet
    canvas.drawLine(
      Offset(cx - 28 * scale, startY + 155 * scale),
      Offset(cx - 38 * scale, startY + 158 * scale),
      paint,
    );
    canvas.drawLine(
      Offset(cx + 20 * scale, startY + 155 * scale),
      Offset(cx + 30 * scale, startY + 158 * scale),
      paint,
    );
  }

  void _drawPhone(Canvas canvas, double cx, double cy, bool isCorrect) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 28, height: 48),
      const Radius.circular(6),
    );

    // Phone body
    final borderPaint = Paint()
      ..color = isCorrect ? Colors.green : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final fillPaint = Paint()
      ..color = (isCorrect ? Colors.green : Colors.red).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, borderPaint);

    // Check or X mark
    if (isCorrect) {
      // Green circle + check
      canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = Colors.green);
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 4, cy), Offset(cx - 1, cy + 4), checkPaint);
      canvas.drawLine(Offset(cx - 1, cy + 4), Offset(cx + 5, cy - 3), checkPaint);
    } else {
      // Red circle + X
      canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = Colors.red);
      final xPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 4, cy - 4), Offset(cx + 4, cy + 4), xPaint);
      canvas.drawLine(Offset(cx + 4, cy - 4), Offset(cx - 4, cy + 4), xPaint);
    }

    // Dashed line from phone to player area
    if (!isCorrect) {
      final dashPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      _drawDashedLine(canvas, Offset(cx, cy - 24), Offset(cx + (cx > 200 ? -30 : 30), cy - 50), dashPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final dashLength = 4.0;
    final gapLength = 3.0;
    final count = (distance / (dashLength + gapLength)).floor();

    for (int i = 0; i < count; i++) {
      final startFraction = i * (dashLength + gapLength) / distance;
      final endFraction = (i * (dashLength + gapLength) + dashLength) / distance;
      canvas.drawLine(
        Offset(start.dx + dx * startFraction, start.dy + dy * startFraction),
        Offset(start.dx + dx * endFraction, start.dy + dy * endFraction),
        paint,
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, double cx, double cy, Color color) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset(cx - painter.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
