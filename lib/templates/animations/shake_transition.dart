import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Adds a short, restrained horizontal shake to draw attention to a child.
/// Drive it with a one-shot animation, such as a controller forwarded on error.
class ShakeTransition extends StatelessWidget {
  const ShakeTransition({
    super.key,
    required this.animation,
    required this.child,
    this.distance = 4,
  });

  final Animation<double> animation;
  final Widget child;
  final double distance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOut.transform(animation.value);
        final offset =
            math.sin(progress * math.pi * 6) * distance * (1 - progress);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
    );
  }
}
