import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ================= GOOGLE LOGO =================
///
/// KEEP THIS LOGO FOR GOOGLE SIGN-IN.
/// This implementation is intentionally preserved.

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.40;
    final strokeWidth = size.shortestSide * 0.14;

    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(rect, -math.pi * 0.9, math.pi * 0.6, false, arcPaint(_red));

    canvas.drawArc(rect, -math.pi * 0.3, math.pi * 0.3, false, arcPaint(_blue));

    canvas.drawArc(rect, math.pi * 0.0, math.pi * 0.5, false, arcPaint(_green));

    canvas.drawArc(
      rect,
      math.pi * 0.5,
      math.pi * 0.5,
      false,
      arcPaint(_yellow),
    );

    final barHeight = strokeWidth;
    final barWidth = size.width * 0.35;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx + barWidth * 0.2, center.dy),
        width: barWidth,
        height: barHeight,
      ),
      Paint()
        ..color = _blue
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) {
    return false;
  }
}

/// ================= LAWYER'S E-DIARY MARK =================
///
/// Modern Legal Editorial mark.
///
/// Concept:
/// - Classical legal architecture
/// - Fountain pen / legal drafting
/// - Partial circular arch
/// - Forest green authority
/// - Restrained antique gold prestige
///
/// Transparent background.
/// No background plate.
/// No glow.
/// No gradients.
/// Suitable for splash, app icon, headers and branding.

class LawFirmMark extends StatelessWidget {
  const LawFirmMark({
    super.key,
    this.width,
    this.gold = const Color(0xFFCCA046),
    this.ink = const Color(0xFF1F3D2B),
  });

  final double? width;
  final Color gold;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Lawyer's E-Diary logo",
      image: true,
      child: Image.asset(
        'assets/images/master logo.png',
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(
          width: width,
          child: const Icon(
            Icons.account_balance_outlined,
            color: Color(0xFFCCA046),
          ),
        ),
      ),
    );
  }
}
