import 'package:flutter/material.dart';

import '../training/progress_rules.dart';
import '../ui/theme/bosyn_text.dart';

/// Dados do resumo de fim de sessão.
class SessionSummary {
  final String training;
  final int correct;
  final int total;
  final Duration duration;

  /// Linha do nível atingido, em linguagem comum (ex.: "Nível de dificuldade: 4 de 7").
  final String? levelLine;

  /// Pontos, recorde e meta (Etapa 10). null = sem recompensa a mostrar.
  final SessionReward? reward;

  /// Minutos treinados hoje, incluindo esta sessão.
  final double? minutesToday;

  const SessionSummary({
    required this.training,
    required this.correct,
    required this.total,
    required this.duration,
    this.levelLine,
    this.reward,
    this.minutesToday,
  });

  int get minutes => (duration.inSeconds / 60).ceil();
}

/// Resumo ao fim de todo treino (achados D3 e E1: antes "Palavras parecidas" e "Conversa no
/// barulho" voltavam para a Home sem dizer nada).
class SessionSummaryScreen extends StatelessWidget {
  final SessionSummary summary;

  const SessionSummaryScreen({super.key, required this.summary});

  /// Troca a tela do treino pelo resumo (a Home recarrega os dados quando a tela do treino sai).
  static void replaceCurrent(BuildContext context, SessionSummary summary) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SessionSummaryScreen(summary: summary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rate = summary.total == 0 ? 0 : (summary.correct * 100 / summary.total).round();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(summary.training, style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Treino concluído', style: BosynText.title),
            const SizedBox(height: 24),
            Text('${summary.correct} de ${summary.total}',
                style: BosynText.title.copyWith(fontSize: 44), textAlign: TextAlign.center),
            Text('acertos ($rate%)', style: BosynText.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _line(Icons.timer_outlined, 'Tempo de treino: ${summary.minutes} min'),
            if (summary.levelLine != null) _line(Icons.trending_up, summary.levelLine!),
            if (summary.reward case final reward?) ...[
              _line(Icons.star_outline, '+${reward.points} pontos de treino'),
              if (reward.newBest) _line(Icons.emoji_events_outlined, 'Novo recorde pessoal neste treino!'),
            ],
            if (summary.minutesToday case final today?)
              _line(
                Icons.flag_outlined,
                today >= ProgressRules.dailyGoalMinutes
                    ? 'Meta de hoje cumprida (${ProgressRules.dailyGoalMinutes} min).'
                    : 'Hoje: ${today.floor()} de ${ProgressRules.dailyGoalMinutes} min.',
              ),
            const SizedBox(height: 20),
            const Text(
              'Errar faz parte: o treino ajusta a dificuldade para você ficar sempre no limite do '
              'que consegue ouvir. É nesse limite que o cérebro aprende.',
              style: BosynText.bodySecondary,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: const Text('Voltar ao início', style: BosynText.button),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: BosynText.body)),
        ]),
      );
}
