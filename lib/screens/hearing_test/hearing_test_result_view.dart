import 'package:flutter/material.dart';

import '../../models/audiogram.dart';
import '../../training/hearing_summary.dart';
import '../../ui/theme/bosyn_text.dart';
import 'audiogram_chart.dart';

/// Resultado do teste (achados C2 e C4): rolável em telas pequenas, gráfico clínico, categoria
/// aproximada por ouvido com o aviso de que é estimativa, e o próximo passo.
class HearingTestResultView extends StatelessWidget {
  final Audiogram audiogram;
  final VoidCallback onSave;
  final VoidCallback onRetest;

  const HearingTestResultView({
    super.key,
    required this.audiogram,
    required this.onSave,
    required this.onRetest,
  });

  @override
  Widget build(BuildContext context) {
    final advice = HearingTestAdvice(audiogram);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Seu resultado', style: BosynText.title),
          const SizedBox(height: 16),
          AudiogramChart(audiogram: audiogram),
          const SizedBox(height: 20),
          _earLine('Ouvido esquerdo', advice.left),
          _earLine('Ouvido direito', advice.right),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BosynText.outline),
            ),
            child: Text(advice.message, style: BosynText.body),
          ),
          const SizedBox(height: 12),
          const Text(
            'Este teste é uma estimativa feita com o seu fone. Não é um exame e não substitui a '
            'audiometria.',
            style: BosynText.bodySecondary,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text('Salvar e continuar', style: BosynText.button),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: onRetest,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Refazer o teste', style: BosynText.button),
            ),
          ),
        ],
      ),
    );
  }

  Widget _earLine(String ear, HearingSummary summary) {
    final details = <String>[
      summary.category,
      if (summary.highFrequencyLoss) 'mais forte nos sons agudos',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$ear: ${details.join(', ')} (estimativa).', style: BosynText.body),
    );
  }
}
