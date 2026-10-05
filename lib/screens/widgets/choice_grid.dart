import 'package:flutter/material.dart';

import 'trial_feedback.dart';

/// Opções de resposta em grade de 2 colunas (2 ou 4 opções), com o destaque do retorno.
class ChoiceGrid extends StatelessWidget {
  final List<String> options;
  final bool enabled;
  final TrialFeedback? feedback;
  final ValueChanged<String> onChoose;

  const ChoiceGrid({
    super.key,
    required this.options,
    required this.enabled,
    required this.feedback,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final option in options)
            SizedBox(
              width: width,
              height: 88,
              child: ElevatedButton(
                onPressed: enabled ? () => onChoose(option) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E24),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: feedbackHighlight(feedback, option) == null
                        ? const BorderSide(color: Colors.white24)
                        : BorderSide(color: feedbackHighlight(feedback, option)!, width: 4),
                  ),
                ),
                child: FittedBox(
                  child: Text(option, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      );
    });
  }
}
