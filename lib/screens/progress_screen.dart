import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/supabase_service.dart';
import '../training/digits_in_noise.dart';
import '../ui/theme/bosyn_text.dart';
import 'digits_in_noise_screen.dart';
import 'hearing_test/audiogram_chart.dart';
import 'hearing_test/hearing_test_flow.dart';

/// "Meu progresso" (achado E1): o paciente revê a medida de fala no ruído ao longo do tempo,
/// o audiograma e os treinos recentes.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  Audiogram? _audiogram;
  List<RehabSession> _history = [];

  static const _names = {
    RehabLevel.phonemicDiscrimination: 'Palavras parecidas',
    RehabLevel.spatialAttention: 'Voz de um lado, barulho do outro',
    RehabLevel.speechInNoise: 'Conversa no barulho',
    RehabLevel.digitsInNoise: 'Audição na fala (medida)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return setState(() => _loading = false);
    try {
      final audiograms = await SupabaseService().getPatientHistory(user.id);
      final history = await SupabaseService().getRehabHistory(user.id);
      if (!mounted) return;
      setState(() {
        _audiogram = audiograms.isEmpty ? null : audiograms.first;
        _history = history;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RehabSession> get _measures => _history
      .where((s) => s.level == RehabLevel.digitsInNoise && s.metadata?['srt_db'] is num)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Future<void> _measure() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DigitsInNoiseScreen(audiogram: _audiogram)));
    if (mounted) _load();
  }

  Future<void> _retest() async {
    final a = await HearingTestFlow.runAndSave(context);
    if (a != null && mounted) setState(() => _audiogram = a);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Meu progresso', style: TextStyle(fontSize: 18))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Audição na fala, no barulho', style: BosynText.heading),
              const SizedBox(height: 8),
              ..._measureSection(),
              const SizedBox(height: 32),
              const Text('Seu teste de audição', style: BosynText.heading),
              const SizedBox(height: 8),
              if (_audiogram == null)
                const Text('Você ainda não fez o teste de audição.', style: BosynText.body)
              else ...[
                Text('Feito em ${_date(_audiogram!.date)}. Estimativa feita com o seu fone, não é exame.',
                    style: BosynText.bodySecondary),
                const SizedBox(height: 12),
                AudiogramChart(audiogram: _audiogram!),
              ],
              TextButton(onPressed: _retest, child: const Text('Refazer o teste de audição', style: TextStyle(fontSize: 16))),
              const SizedBox(height: 32),
              const Text('Treinos recentes', style: BosynText.heading),
              const SizedBox(height: 8),
              if (_history.isEmpty) const Text('Nenhum treino ainda.', style: BosynText.body),
              for (final s in _history.reversed.take(15))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_names[s.level] ?? 'Treino', style: BosynText.body),
                  subtitle: Text('${_date(s.date)} · ${s.correctAnswers} de ${s.totalTrials} certos',
                      style: BosynText.bodySecondary),
                ),
            ]),
    );
  }

  List<Widget> _measureSection() {
    final measures = _measures;
    final due = DinProcedure.isDue(_history);
    return [
      if (measures.isEmpty)
        const Text('Ainda sem medida. Ela mostra, a cada 14 dias, se você está entendendo melhor '
            'a fala no barulho.', style: BosynText.body)
      else ...[
        Text(DinProcedure.describe((measures.last.metadata!['srt_db'] as num).toDouble()), style: BosynText.body),
        const SizedBox(height: 12),
        if (measures.length >= 2) _srtChart(measures),
        const Text('Mais para baixo = melhor (entendeu com mais ruído). Medida interna do app, não é exame.',
            style: BosynText.caption),
      ],
      const SizedBox(height: 12),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _measure,
          style: ElevatedButton.styleFrom(
            backgroundColor: due ? const Color(0xFF2563EB) : const Color(0xFF2A2A33),
            foregroundColor: Colors.white,
          ),
          child: Text(due ? 'Medir agora (uns 4 minutos)' : 'Medir de novo', style: BosynText.button),
        ),
      ),
    ];
  }

  Widget _srtChart(List<RehabSession> measures) => SizedBox(
        height: 180,
        child: LineChart(LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < measures.length; i++)
                  FlSpot(i.toDouble(), (measures[i].metadata!['srt_db'] as num).toDouble()),
              ],
              color: const Color(0xFF4ADE80),
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(_date(measures[v.toInt()].date), style: BosynText.caption),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: BosynText.caption),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
        )),
      );
}
