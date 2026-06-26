import 'package:flutter/material.dart';
import '../../core/theme/app_gradients.dart';

class GlowDivider extends StatelessWidget {
  final double height;
  final double margin;

  const GlowDivider({super.key, this.height = 2, this.margin = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: EdgeInsets.symmetric(vertical: margin),
      decoration: const BoxDecoration(gradient: AppGradients.glowDivider),
    );
  }
}
