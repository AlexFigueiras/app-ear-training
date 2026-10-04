import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../audio_engine/audibility_profile.dart';
import '../../models/audiogram.dart';
import '../../ui/theme/bosyn_text.dart';

/// Audiograma no formato clínico (achado C4 da auditoria de UX):
/// - frequências em ordem crescente (250 → 8000), não na ordem do teste;
/// - nível de cima para baixo (audição melhor em cima), com valores positivos no eixo e no toque;
/// - legenda: ouvido esquerdo em azul com ×, direito em vermelho com ○;
/// - "sem resposta" listado abaixo do gráfico.
class AudiogramChart extends StatelessWidget {
  final Audiogram audiogram;

  const AudiogramChart({super.key, required this.audiogram});

  static const _left = Color(0xFF60A5FA);
  static const _right = Color(0xFFF87171);
  static const _frequencies = AudibilityProfile.bands;

  static String _label(int f) => f >= 1000 ? '${f ~/ 1000}k' : '$f';

  LineChartBarData _line(List<AudiometryPoint> points, Color color, bool cross) {
    final spots = <FlSpot>[
      for (final p in points)
        if (_frequencies.contains(p.frequency))
          FlSpot(_frequencies.indexOf(p.frequency).toDouble(), -p.threshold),
    ]..sort((a, b) => a.x.compareTo(b.x));
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => cross
            ? FlDotCrossPainter(size: 12, width: 2.5, color: color)
            : FlDotCirclePainter(radius: 5, color: Colors.transparent, strokeColor: color, strokeWidth: 2.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noResponse = [
      for (final p in audiogram.leftEar)
        if (p.noResponse) 'esquerdo ${_label(p.frequency)} Hz',
      for (final p in audiogram.rightEar)
        if (p.noResponse) 'direito ${_label(p.frequency)} Hz',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260,
          child: LineChart(LineChartData(
            minX: 0,
            maxX: (_frequencies.length - 1).toDouble(),
            minY: -85,
            maxY: 0,
            lineBarsData: [
              _line(audiogram.leftEar, _left, true),
              _line(audiogram.rightEar, _right, false),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.barIndex == 0 ? 'Esq.' : 'Dir.'} ${_label(_frequencies[s.x.toInt()])} Hz: '
                      '${(-s.y).toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                ],
              ),
            ),
            gridData: const FlGridData(show: true, horizontalInterval: 10, verticalInterval: 1),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(
                axisNameWidget: const Text('Frequência (Hz)', style: BosynText.caption),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, _) => Text(_label(_frequencies[v.toInt()]), style: BosynText.caption),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 20,
                  getTitlesWidget: (v, _) => Text((-v).toStringAsFixed(0), style: BosynText.caption),
                ),
              ),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
          )),
        ),
        const SizedBox(height: 8),
        const Wrap(spacing: 16, children: [
          _LegendItem(color: _left, label: '× Ouvido esquerdo'),
          _LegendItem(color: _right, label: '○ Ouvido direito'),
        ]),
        const SizedBox(height: 4),
        const Text('Mais acima = ouviu sons mais baixos.', style: BosynText.caption),
        if (noResponse.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Não ouviu nem no volume máximo: ${noResponse.join(', ')}.', style: BosynText.caption),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600));
}
