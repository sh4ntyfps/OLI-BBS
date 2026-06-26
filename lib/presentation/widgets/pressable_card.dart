import 'package:flutter/material.dart';

class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;
  final Color? color;
  final List<BoxShadow>? shadow;
  final bool enableTilt;
  final Gradient? gradient;

  const PressableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.color,
    this.shadow,
    this.enableTilt = false,
    this.gradient,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? Theme.of(context).cardTheme.color ?? Colors.white;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      decoration: BoxDecoration(
        color: widget.gradient != null ? null : cardColor,
        gradient: widget.gradient,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
        boxShadow: widget.shadow ?? [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withAlpha(13),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
        child: widget.child,
      ),
    );

    if (widget.enableTilt) {
      card = LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanUpdate: (details) {
              final rect = context.findRenderObject()!.paintBounds;
              final cx = rect.width / 2;
              final cy = rect.height / 2;
              setState(() {
                _tiltY = ((details.localPosition.dx - cx) / cx).clamp(-1.0, 1.0) * 8;
                _tiltX = ((details.localPosition.dy - cy) / cy).clamp(-1.0, 1.0) * -8;
              });
            },
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) {
              _controller.reverse();
              setState(() {
                _tiltX = 0;
                _tiltY = 0;
              });
            },
            onTapCancel: () {
              _controller.reverse();
              setState(() {
                _tiltX = 0;
                _tiltY = 0;
              });
            },
            onTap: widget.onTap,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 0, 0)
                ..rotateX(_tiltX * 0.0174533)
                ..rotateY(_tiltY * 0.0174533),
              child: card,
            ),
          );
        },
      );
    } else {
      card = GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: card,
        ),
      );
    }

    return card;
  }
}
