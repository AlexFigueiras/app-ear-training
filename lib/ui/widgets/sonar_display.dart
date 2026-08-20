import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Componente Sonar / Radar com animação de varredura e visualização de frequência
class SonarDisplay extends StatelessWidget {
  final AnimationController animationController;
  final int freqBand;
  final bool isPulse;
  final double angle;

  const SonarDisplay({
    super.key,
    required this.animationController,
    required this.freqBand,
    this.isPulse = false,
    this.angle = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: animationController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(250, 250),
              painter: SonarPainter(animationController.value, angle, isPulse),
            );
          },
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$freqBand HZ",
              style: const TextStyle(
                color: Color(0xFF00FF41),
                fontSize: 22,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "TRACKING ALIVE",
              style: TextStyle(color: Colors.white24, fontSize: 8),
            ),
          ],
        ),
      ],
    );
  }
}

class SonarPainter extends CustomPainter {
  final double progress;
  final double angle;
  final bool isPulse;

  SonarPainter(this.progress, this.angle, this.isPulse);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Grades do Sonar
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.6, paint);

    // Linha de Panning
    final linePaint = Paint()
      ..color = const Color(0xFF00FF41).withOpacity(0.2)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      center,
      center +
          Offset(
            angle * radius,
            -math.sqrt(
              math.max(0.0, radius * radius - (angle * radius) * (angle * radius)),
            ),
          ),
      linePaint,
    );

    if (isPulse && progress > 0) {
      final pulsePaint = Paint()
        ..color = const Color(0xFF00FF41).withOpacity((1.0 - progress).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      // Ping na direção do ângulo
      final pingPos =
          center +
          Offset(
            angle * radius,
            -math.sqrt(
                  math.max(0.0, radius * radius - (angle * radius) * (angle * radius)),
                ) *
                0.8,
          );
      canvas.drawCircle(pingPos, 30 * progress, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(SonarPainter oldDelegate) => true;
}
