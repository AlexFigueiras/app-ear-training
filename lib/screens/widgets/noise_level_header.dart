import 'package:flutter/material.dart';

import '../../training/progress_rules.dart';
import '../../ui/theme/bosyn_text.dart';

/// Cabeçalho do treino com ruído: nível de ruído em linguagem comum (sem "SNR" nem dB, achado
/// D5). SNR +15 dB = nível 1 (fácil) ... -10 dB = nível 10 (difícil).
class NoiseLevelHeader extends StatelessWidget {
  final double snrDb;

  const NoiseLevelHeader({super.key, required this.snrDb});

  static int levelOf(double snrDb) => ProgressRules.noiseLevel(snrDb);

  @override
  Widget build(BuildContext context) {
    final level = levelOf(snrDb);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Expanded(child: Text('Nível de ruído', style: BosynText.body)),
        Text('$level de 10', style: BosynText.heading.copyWith(color: level >= 6 ? Colors.orange : Colors.greenAccent)),
      ]),
    );
  }
}
