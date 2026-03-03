import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool showAngles;

  PosePainter(this.poses, this.imageSize, this.rotation, {this.showAngles = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.greenAccent;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    for (final pose in poses) {
      // Draw landmarks as dots
      pose.landmarks.forEach((_, landmark) {
        final offset = Offset(
          translateX(landmark.x, size, imageSize, rotation),
          translateY(landmark.y, size, imageSize, rotation),
        );
        canvas.drawCircle(offset, 4, dotPaint);
        canvas.drawCircle(offset, 4, paint..style = PaintingStyle.stroke);
      });

      paint.style = PaintingStyle.stroke;

      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final joint1 = pose.landmarks[type1];
        final joint2 = pose.landmarks[type2];
        if (joint1 != null && joint2 != null) {
          canvas.drawLine(
              Offset(translateX(joint1.x, size, imageSize, rotation),
                  translateY(joint1.y, size, imageSize, rotation)),
              Offset(translateX(joint2.x, size, imageSize, rotation),
                  translateY(joint2.y, size, imageSize, rotation)),
              paintType);
        }
      }

      // Draw arms
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      // Draw Body
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, paint);
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, paint);

      // Draw legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);

      // Draw angle labels
      if (showAngles) {
        _drawAngle(canvas, size, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, '팔꿈치L');
        _drawAngle(canvas, size, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, '팔꿈치R');
        _drawAngle(canvas, size, pose, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, '무릎L');
        _drawAngle(canvas, size, pose, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, '무릎R');
        _drawAngle(canvas, size, pose, PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, '어깨L');
        _drawAngle(canvas, size, pose, PoseLandmarkType.rightElbow, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, '어깨R');
      }
    }
  }

  void _drawAngle(Canvas canvas, Size canvasSize, Pose pose,
      PoseLandmarkType type1, PoseLandmarkType typeCenter, PoseLandmarkType type3, String label) {
    final p1 = pose.landmarks[type1];
    final pc = pose.landmarks[typeCenter];
    final p3 = pose.landmarks[type3];
    if (p1 == null || pc == null || p3 == null) return;

    final angle = _calculateAngle(p1, pc, p3);
    final centerX = translateX(pc.x, canvasSize, imageSize, rotation);
    final centerY = translateY(pc.y, canvasSize, imageSize, rotation);

    // Determine color based on angle safety
    Color bgColor;
    if (label.contains('팔꿈치')) {
      bgColor = angle < 140 ? Colors.red : (angle < 155 ? Colors.orange : Colors.green);
    } else if (label.contains('무릎')) {
      bgColor = angle < 90 ? Colors.red : (angle < 120 ? Colors.orange : Colors.green);
    } else {
      bgColor = Colors.blueAccent;
    }

    final textSpan = TextSpan(
      text: '${angle.toInt()}°',
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX + 20, centerY - 12), width: textPainter.width + 10, height: 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(bgRect, Paint()..color = bgColor.withOpacity(0.85));
    textPainter.paint(canvas, Offset(centerX + 20 - textPainter.width / 2, centerY - 12 - textPainter.height / 2));
  }

  double _calculateAngle(PoseLandmark p1, PoseLandmark center, PoseLandmark p3) {
    final v1 = math.Point(p1.x - center.x, p1.y - center.y);
    final v2 = math.Point(p3.x - center.x, p3.y - center.y);
    final dot = v1.x * v2.x + v1.y * v2.y;
    final mag1 = math.sqrt(v1.x * v1.x + v1.y * v1.y);
    final mag2 = math.sqrt(v2.x * v2.x + v2.y * v2.y);
    if (mag1 == 0 || mag2 == 0) return 0;
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cosAngle) * 180 / math.pi;
  }

  /// Calculates key joint angles from the first detected pose.
  /// Returns map with elbow, shoulder, knee angles.
  static Map<String, double> getJointAngles(List<Pose> poses) {
    if (poses.isEmpty) return {};
    final pose = poses.first;

    double calcAngle(PoseLandmarkType t1, PoseLandmarkType tc, PoseLandmarkType t3) {
      final p1 = pose.landmarks[t1];
      final pc = pose.landmarks[tc];
      final p3 = pose.landmarks[t3];
      if (p1 == null || pc == null || p3 == null) return 0;
      final v1x = p1.x - pc.x, v1y = p1.y - pc.y;
      final v2x = p3.x - pc.x, v2y = p3.y - pc.y;
      final dot = v1x * v2x + v1y * v2y;
      final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
      final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
      if (mag1 == 0 || mag2 == 0) return 0;
      return math.acos((dot / (mag1 * mag2)).clamp(-1.0, 1.0)) * 180 / math.pi;
    }

    return {
      'rightElbow': calcAngle(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
      'leftElbow': calcAngle(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
      'rightShoulder': calcAngle(PoseLandmarkType.rightElbow, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
      'leftShoulder': calcAngle(PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
      'rightKnee': calcAngle(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
      'leftKnee': calcAngle(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    };
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.poses != poses;
  }

  double translateX(double x, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * canvasSize.width / imageSize.height;
      case InputImageRotation.rotation270deg:
        return canvasSize.width - x * canvasSize.width / imageSize.height;
      default:
        return x * canvasSize.width / imageSize.width;
    }
  }

  double translateY(double y, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvasSize.height / imageSize.width;
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }
}
