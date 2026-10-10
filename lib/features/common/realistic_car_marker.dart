import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A realistic top-down navigation vehicle marker with metallic chassis,
/// headlights glow, windshield reflections, side mirrors, and dynamic heading.
class RealisticCarMarker extends StatelessWidget {
  final double heading; // 0..360 degrees
  final double size;
  final bool isLive;

  const RealisticCarMarker({
    super.key,
    this.heading = 0,
    this.size = 56,
    this.isLive = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient pulse/radar halo
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBlue.withValues(alpha: 0.14),
              border: Border.all(color: kBlue.withValues(alpha: 0.35), width: 1.5),
            ),
          ),
          // Heading rotated vehicle
          Transform.rotate(
            angle: heading * (math.pi / 180.0),
            child: CustomPaint(
              size: Size(size * 0.72, size * 0.72),
              painter: _CarPainter(isLive: isLive),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  final bool isLive;
  const _CarPainter({required this.isLive});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Headlight beam cones (subtle glowing yellow/white light projecting forward)
    final beamPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.amberAccent.withValues(alpha: 0.35),
          Colors.amberAccent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(center.dx, center.dy - h * 0.4), radius: w * 0.6));

    final beamPath = Path()
      ..moveTo(center.dx - w * 0.22, center.dy - h * 0.35)
      ..lineTo(center.dx - w * 0.48, center.dy - h * 0.85)
      ..lineTo(center.dx + w * 0.48, center.dy - h * 0.85)
      ..lineTo(center.dx + w * 0.22, center.dy - h * 0.35)
      ..close();
    canvas.drawPath(beamPath, beamPaint);

    // 2. Realistic Soft Drop Shadow beneath car
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    final shadowRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 2), width: w * 0.48, height: h * 0.82),
      const Radius.circular(8),
    );
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 3. Side Mirrors
    final mirrorPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - w * 0.31, center.dy - h * 0.18, w * 0.08, h * 0.12),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + w * 0.23, center.dy - h * 0.18, w * 0.08, h * 0.12),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    // 4. Car Main Chassis Body (Sleek deep navy/blue metallic with rounded aerodynamic corners)
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2563EB), // Electric blue front
          Color(0xFF1E3A8A), // Deep navy center
          Color(0xFF0F172A), // Dark navy rear
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final bodyRRect = RRect.fromRectAndCorners(
      Rect.fromCenter(center: center, width: w * 0.46, height: h * 0.80),
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: const Radius.circular(6),
      bottomRight: const Radius.circular(6),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    // Body Border / Metallic highlight stroke
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bodyRRect, strokePaint);

    // 5. Front Windshield (curved dark cyan/slate glass with light sheen)
    final glassPaint = Paint()..color = const Color(0xFF0F172A);
    final windshieldPath = Path()
      ..moveTo(center.dx - w * 0.16, center.dy - h * 0.10)
      ..lineTo(center.dx - w * 0.14, center.dy - h * 0.24)
      ..quadraticBezierTo(center.dx, center.dy - h * 0.27, center.dx + w * 0.14, center.dy - h * 0.24)
      ..lineTo(center.dx + w * 0.16, center.dy - h * 0.10)
      ..close();
    canvas.drawPath(windshieldPath, glassPaint);

    // Glass glossy highlight
    final glassGlossPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(windshieldPath, glassGlossPaint);

    // 6. Car Roof Top
    final roofPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF3B82F6),
          Color(0xFF1D4ED8),
        ],
      ).createShader(Rect.fromCenter(center: center, width: w * 0.36, height: h * 0.30));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + h * 0.04), width: w * 0.34, height: h * 0.26),
        const Radius.circular(4),
      ),
      roofPaint,
    );

    // 7. Rear Windshield
    final rearGlassPath = Path()
      ..moveTo(center.dx - w * 0.15, center.dy + h * 0.19)
      ..lineTo(center.dx - w * 0.14, center.dy + h * 0.27)
      ..quadraticBezierTo(center.dx, center.dy + h * 0.29, center.dx + w * 0.14, center.dy + h * 0.27)
      ..lineTo(center.dx + w * 0.15, center.dy + h * 0.19)
      ..close();
    canvas.drawPath(rearGlassPath, glassPaint);

    // 8. Front Headlights (bright xenon glow)
    final headlightPaint = Paint()..color = const Color(0xFFFEF08A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - w * 0.20, center.dy - h * 0.39, w * 0.09, h * 0.06),
        const Radius.circular(2),
      ),
      headlightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + w * 0.11, center.dy - h * 0.39, w * 0.09, h * 0.06),
        const Radius.circular(2),
      ),
      headlightPaint,
    );

    // 9. Rear LED Taillights (vibrant red)
    final taillightPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - w * 0.20, center.dy + h * 0.34, w * 0.08, h * 0.05),
        const Radius.circular(1.5),
      ),
      taillightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + w * 0.12, center.dy + h * 0.34, w * 0.08, h * 0.05),
        const Radius.circular(1.5),
      ),
      taillightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CarPainter oldDelegate) => oldDelegate.isLive != isLive;
}
