import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/gamification_controller.dart';

/// Medidor de Signal-to-Noise Ratio com alerta visual crítico
class SNRMeter extends StatelessWidget {
  const SNRMeter({super.key});

  @override
  Widget build(BuildContext context) {
    final snr = context.watch<GamificationController>().currentSNR;
    final bool isCritical = snr <= 4.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCritical
            ? const Color(0xFFE11D48).withOpacity(0.1)
            : const Color(0xFF1A1A1A),
        border: Border.all(
          color: isCritical ? const Color(0xFFE11D48) : const Color(0xFF333333),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "SIGNAL-TO-NOISE RATIO",
                style: TextStyle(color: Colors.white38, fontSize: 8),
              ),
              Text(
                "${snr.toStringAsFixed(1)} dB",
                style: TextStyle(
                  color: isCritical
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF00FF41),
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: ((snr + 10) / 30).clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(
              isCritical ? const Color(0xFFE11D48) : const Color(0xFF00FF41),
            ),
            minHeight: 2.0,
          ),
        ],
      ),
    );
  }
}
