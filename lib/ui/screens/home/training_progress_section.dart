import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/rehab_session.dart';
import '../../../training/progress_rules.dart';
import '../home_widgets.dart';

/// Evolução por treino (Etapa 10; achado E3): um gráfico pequeno por treino, com o NÍVEL
/// alcançado em cada sessão e as datas. O gráfico antigo misturava o acerto de exercícios
/// diferentes, e o acerto é justamente o que a escada adaptativa mantém constante.
class TrainingProgressSection extends StatelessWidget {
  final List<RehabSession> history;

  const TrainingProgressSection({super.key, required this.history});

  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final t in TrainingId.values) {
      final points = [
        for (final s in history)
          if (s.level == t.level && ProgressRules.sessionLevel(s) != null) (s.date, ProgressRules.sessionLevel(s)!),
      ];
      if (points.isEmpty) continue;
      final recent = points.length > 10 ? points.sublist(points.length - 10) : points;
      rows.add(_TrainingChart(training: t, points: recent));
    }
    if (rows.isEmpty) return const EmptyProgressNote();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _TrainingChart extends StatelessWidget {
  final TrainingId training;
  final List<(DateTime, int)> points;

  const _TrainingChart({required this.training, required this.points});

  @override
  Widget build(BuildContext context) {
    final last = points.last.$2;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: HomeColors.surface,
        border: Border.all(color: HomeColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(training.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        Text('Nível $last de ${training.maxLevel} · ${ProgressRules.stageName(last, training.maxLevel)}',
            style: const TextStyle(color: HomeColors.textSecondary, fontSize: 15)),
        if (points.length >= 2)
          SizedBox(
            height: 110,
            child: LineChart(LineChartData(
              minY: 1,
              maxY: training.maxLevel.toDouble(),
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].$2.toDouble())],
                  color: HomeColors.accent,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: points.length > 5 ? 2 : 1,
                    getTitlesWidget: (v, _) => Text(TrainingProgressSection._date(points[v.toInt()].$1),
                        style: const TextStyle(color: HomeColors.textSecondary, fontSize: 14)),
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            )),
          ),
      ]),
    );
  }
}
