import 'package:flutter/material.dart';

import '../../../training/progress_rules.dart';
import '../home_widgets.dart';

/// Meta do dia em minutos, semana e sequência (Etapa 10; achado E3). Substitui "XP ACUMULADO",
/// "STREAK" (que subia a cada abertura da Home) e "SESSÕES HOJE: 3 / 2".
class DailyGoalCard extends StatelessWidget {
  final double minutesToday;
  final int streakDays;
  final int goalDaysThisWeek;
  final int points;

  const DailyGoalCard({
    super.key,
    required this.minutesToday,
    required this.streakDays,
    required this.goalDaysThisWeek,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    const goal = ProgressRules.dailyGoalMinutes;
    final met = minutesToday >= goal;
    final shown = minutesToday.floor().clamp(0, 999);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeColors.surface,
        border: Border.all(color: met ? HomeColors.accent : HomeColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          met ? 'Meta de hoje cumprida!' : 'Hoje: $shown de $goal min de treino',
          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (minutesToday / goal).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(met ? HomeColors.accent : HomeColors.primaryButton),
          ),
        ),
        const SizedBox(height: 14),
        _row(Icons.calendar_today_outlined,
            'Esta semana: $goalDaysThisWeek de ${ProgressRules.weeklyGoalDays} dias com a meta'),
        _row(Icons.local_fire_department_outlined, 'Dias seguidos com a meta: ${ProgressRules.days(streakDays)}'),
        _row(Icons.star_outline, 'Pontos de treino: $points'),
        if (minutesToday >= 2 * goal)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Você já treinou bastante hoje. Pausas também ajudam o cérebro a guardar o que aprendeu.',
              style: TextStyle(color: HomeColors.textSecondary, fontSize: 15, height: 1.4),
            ),
          ),
      ]),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Icon(icon, color: HomeColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))),
        ]),
      );
}
