import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter that draws a side-view badminton smash pose as recording guide.
/// Based on actual smash motion: player jumping with racket arm extended overhead.
class RecordingGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    // Draw the main smash pose (side view) in center
    _drawSmashPlayer(canvas, centerX, size);

    // Camera position indicators
    final camY = size.height * 0.42;

    // Correct: side view (left side)
    _drawCameraIcon(canvas, centerX - size.width * 0.38, camY, true);
    _drawLabel(canvas, '측면', centerX - size.width * 0.38, camY + 32,
        const Color(0xFF22C55E));

    // Incorrect: back view (right side)
    _drawCameraIcon(canvas, centerX + size.width * 0.38, camY, false);
    _drawLabel(canvas, '후면', centerX + size.width * 0.38, camY + 32,
        const Color(0xFFEF4444));
  }

  void _drawSmashPlayer(Canvas canvas, double cx, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF94A3B8).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final scale = size.height / 300;
    final startY = size.height * 0.08;

    // --- Side-view smash pose (player facing right, jumping) ---

    // Head
    final headCx = cx + 2 * scale;
    final headCy = startY + 38 * scale;
    canvas.drawCircle(Offset(headCx, headCy), 14 * scale, paint);
    canvas.drawCircle(Offset(headCx, headCy), 14 * scale, fillPaint);

    // Neck
    canvas.drawLine(
      Offset(headCx, headCy + 14 * scale),
      Offset(cx, startY + 60 * scale),
      paint,
    );

    // Torso (slightly arched back for smash)
    final shoulderPos = Offset(cx, startY + 60 * scale);
    final hipPos = Offset(cx - 8 * scale, startY + 115 * scale);
    canvas.drawLine(shoulderPos, hipPos, paint);

    // --- Racket arm (right arm - extended high overhead) ---
    // Upper arm going up-back
    final rShoulderX = cx + 5 * scale;
    final rElbow = Offset(cx + 18 * scale, startY + 32 * scale);
    canvas.drawLine(
      Offset(rShoulderX, startY + 60 * scale),
      rElbow,
      paint,
    );
    // Forearm extending up to racket
    final rHand = Offset(cx + 28 * scale, startY + 8 * scale);
    canvas.drawLine(rElbow, rHand, paint);

    // Racket
    final racketPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Handle
    final racketBase = Offset(cx + 32 * scale, startY - 5 * scale);
    canvas.drawLine(rHand, racketBase, racketPaint);

    // Racket head (oval)
    canvas.save();
    canvas.translate(racketBase.dx + 3 * scale, racketBase.dy - 12 * scale);
    canvas.rotate(-0.2);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: 20 * scale, height: 26 * scale),
      racketPaint,
    );
    canvas.restore();

    // --- Left arm (non-racket arm - extended forward for balance) ---
    final lShoulderX = cx - 5 * scale;
    final lElbow = Offset(cx + 20 * scale, startY + 72 * scale);
    canvas.drawLine(
      Offset(lShoulderX, startY + 62 * scale),
      lElbow,
      paint,
    );
    final lHand = Offset(cx + 35 * scale, startY + 65 * scale);
    canvas.drawLine(lElbow, lHand, paint);

    // --- Legs (jumping / scissors kick position) ---
    // Right leg (front, slightly bent forward)
    final rHip = Offset(hipPos.dx + 6 * scale, hipPos.dy);
    final rKnee = Offset(cx + 15 * scale, startY + 145 * scale);
    final rFoot = Offset(cx + 22 * scale, startY + 178 * scale);
    canvas.drawLine(rHip, rKnee, paint);
    canvas.drawLine(rKnee, rFoot, paint);
    // Foot
    canvas.drawLine(
        rFoot, Offset(rFoot.dx + 10 * scale, rFoot.dy + 2 * scale), paint);

    // Left leg (back, bent behind)
    final lHip = Offset(hipPos.dx - 4 * scale, hipPos.dy);
    final lKnee = Offset(cx - 25 * scale, startY + 148 * scale);
    final lFoot = Offset(cx - 18 * scale, startY + 170 * scale);
    canvas.drawLine(lHip, lKnee, paint);
    canvas.drawLine(lKnee, lFoot, paint);
    // Foot
    canvas.drawLine(
        lFoot, Offset(lFoot.dx - 8 * scale, lFoot.dy + 3 * scale), paint);

    // --- Shuttlecock (small, above racket) ---
    _drawShuttlecock(canvas, cx + 36 * scale, startY - 28 * scale, scale);

    // --- Ground shadow (subtle) ---
    final shadowPaint = Paint()
      ..color = const Color(0xFF94A3B8).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, startY + 190 * scale),
        width: 60 * scale,
        height: 8 * scale,
      ),
      shadowPaint,
    );
  }

  void _drawShuttlecock(Canvas canvas, double cx, double cy, double scale) {
    final paint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Cork (small circle)
    canvas.drawCircle(Offset(cx, cy + 4 * scale), 3 * scale, paint);
    canvas.drawCircle(
      Offset(cx, cy + 4 * scale),
      3 * scale,
      Paint()
        ..color = const Color(0xFF64748B).withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    // Feathers (fan shape going up)
    for (var i = -2; i <= 2; i++) {
      final angle = i * 0.25;
      canvas.drawLine(
        Offset(cx, cy + 1 * scale),
        Offset(cx + math.sin(angle) * 8 * scale,
            cy - math.cos(angle) * 10 * scale),
        paint,
      );
    }
  }

  void _drawCameraIcon(Canvas canvas, double cx, double cy, bool isCorrect) {
    final color = isCorrect ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    // Phone body
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 50),
      const Radius.circular(6),
    );
    canvas.drawRRect(
        rect,
        Paint()
          ..color = color.withOpacity(0.08)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // Check or X icon
    if (isCorrect) {
      canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = color);
      final p = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 4, cy), Offset(cx - 1, cy + 4), p);
      canvas.drawLine(Offset(cx - 1, cy + 4), Offset(cx + 5, cy - 3), p);
    } else {
      canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = color);
      final p = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 4, cy - 4), Offset(cx + 4, cy + 4), p);
      canvas.drawLine(Offset(cx + 4, cy - 4), Offset(cx - 4, cy + 4), p);
    }
  }

  void _drawLabel(
      Canvas canvas, String text, double cx, double cy, Color color) {
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
