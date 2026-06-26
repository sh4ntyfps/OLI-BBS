import 'package:flutter/material.dart';

class PosePainter extends CustomPainter {
  final List<dynamic> poses;
  final Size imageSize;
  final dynamic rotation;

  PosePainter(this.poses, this.imageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(PosePainter oldDelegate) => false;
}
