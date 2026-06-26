import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient primaryToSecondary = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryToTertiary = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroText = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFF97316)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient glowDivider = LinearGradient(
    colors: [Colors.transparent, Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFF97316), Colors.transparent],
    stops: [0.0, 0.3, 0.5, 0.7, 1.0],
  );

  static const LinearGradient sosGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static BoxDecoration primaryButton({
    double borderRadius = 18,
    List<Color>? colors,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        colors: colors ?? [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2563EB).withAlpha(74),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

