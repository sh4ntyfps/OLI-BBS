import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;

  PosePainter(this.poses, this.imageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pointPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3.0;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        final x = _translateX(landmark.x, size);
        final y = _translateY(landmark.y, size);
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
      });

      _drawConnection(canvas, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, size, linePaint);
      _drawConnection(canvas, pose, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, size, linePaint);
      _drawConnection(canvas, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, size, linePaint);
      _drawConnection(canvas, pose, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, size, linePaint);
    }
  }

  void _drawConnection(Canvas canvas, Pose pose, PoseLandmarkType startType, PoseLandmarkType endType, Size size, Paint paint) {
    final start = pose.landmarks[startType];
    final end = pose.landmarks[endType];
    if (start != null && end != null) {
      canvas.drawLine(
        Offset(_translateX(start.x, size), _translateY(start.y, size)),
        Offset(_translateX(end.x, size), _translateY(end.y, size)),
        paint,
      );
    }
  }

  double _translateX(double x, Size size) => x * size.width / imageSize.width;
  double _translateY(double y, Size size) => y * size.height / imageSize.height;

  @override
  bool shouldRepaint(PosePainter oldDelegate) => oldDelegate.poses != poses;
}
