import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/gamification_controller.dart';

/// Barra segmentada de Energia Neural reativa
class NeuralEnergyBar extends StatelessWidget {
  final int maxSegments;

  const NeuralEnergyBar({super.key, this.maxSegments = 5});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GamificationController>();

    return Row(
      children: List.generate(
        maxSegments,
        (index) => Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: index < controller.neuralEnergy
                ? const Color(0xFF00FF41)
                : Colors.white12,
          ),
        ),
      ),
    );
  }
}
