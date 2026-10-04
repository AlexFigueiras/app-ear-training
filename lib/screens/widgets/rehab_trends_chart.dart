import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/rehab_session.dart';

class RehabTrendsChart extends StatelessWidget {
  final List<RehabSession> sessions;
  const RehabTrendsChart({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(child: Text("Nenhuma sessão registrada", style: TextStyle(color: Colors.grey)));
    }

    // Identifica fonemas mais difíceis (Gaps de Performance)
    Map<String, int> errorsByPair = {};
    for (var s in sessions) {
      if (s.metadata != null && s.metadata!['log'] != null) {
        for (var trial in s.metadata!['log']) {
          if (trial['correct'] == false) {
            String pair = trial['pair'] ?? "Desconhecido";
            errorsByPair[pair] = (errorsByPair[pair] ?? 0) + 1;
          }
        }
      }
    }

    String criticalGap = "Nenhum detectado";
    if (errorsByPair.isNotEmpty) {
      criticalGap = errorsByPair.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("EVOLUÇÃO DA ACURÁCIA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text("CRITICAL GAP: $criticalGap", style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(sessions.length, (i) => FlSpot(i.toDouble(), sessions[i].accuracy)),
                  isCurved: true,
                  color: Colors.greenAccent,
                  barWidth: 4,
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [Colors.greenAccent.withValues(alpha: 0.2), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }
}
