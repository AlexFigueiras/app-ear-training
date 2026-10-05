import 'package:flutter/material.dart';

import '../../ui/theme/bosyn_text.dart';

/// Resultado de uma tentativa, mostrado logo depois da resposta (achado D3: antes o único
/// retorno era uma vibração, e o paciente não sabia qual era a certa).
class TrialFeedback {
  final bool correct;
  final String correctAnswer;
  final String selected;

  const TrialFeedback({required this.correct, required this.correctAnswer, required this.selected});
}

/// Cores do retorno (contraste AA sobre o fundo escuro).
class FeedbackColors {
  const FeedbackColors._();
  static const correct = Color(0xFF4ADE80);
  static const wrong = Color(0xFFF87171);
}

/// Faixa de retorno: ✓/✗ grande, a resposta certa e, no erro, "Ouvir as duas" para comparar
/// (feedback contrastivo) e "Continuar". No acerto a tela avança sozinha.
class FeedbackBanner extends StatelessWidget {
  final TrialFeedback feedback;

  /// Toca a certa e depois a outra. null = não se aplica (ex.: treino de direção).
  final VoidCallback? onListenBoth;
  final VoidCallback? onContinue;

  /// Texto do que está tocando agora durante "Ouvir as duas" (ex.: 'Certa: "sala"').
  final String? nowPlaying;

  const FeedbackBanner({
    super.key,
    required this.feedback,
    this.onListenBoth,
    this.onContinue,
    this.nowPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final color = feedback.correct ? FeedbackColors.correct : FeedbackColors.wrong;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(feedback.correct ? Icons.check_circle : Icons.cancel, color: color, size: 40),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  feedback.correct ? 'Certo!' : 'Era "${feedback.correctAnswer}"',
                  style: BosynText.title.copyWith(color: color),
                ),
              ),
            ]),
            if (!feedback.correct) ...[
              const SizedBox(height: 4),
              Text('Você marcou "${feedback.selected}".', style: BosynText.body),
            ],
            if (nowPlaying != null) ...[
              const SizedBox(height: 8),
              Text(nowPlaying!, style: BosynText.heading),
            ],
            if (onListenBoth != null || onContinue != null) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                if (onListenBoth != null)
                  OutlinedButton.icon(
                    onPressed: onListenBoth,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Ouvir as duas', style: TextStyle(fontSize: 18)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(48, 52)),
                  ),
                if (onContinue != null)
                  ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 52),
                    ),
                    child: const Text('Continuar', style: TextStyle(fontSize: 18)),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Destaque de uma opção enquanto o retorno está na tela: verde na certa, vermelho na marcada.
Color? feedbackHighlight(TrialFeedback? feedback, String option) {
  if (feedback == null) return null;
  if (option == feedback.correctAnswer) return FeedbackColors.correct;
  if (option == feedback.selected) return FeedbackColors.wrong;
  return null;
}
