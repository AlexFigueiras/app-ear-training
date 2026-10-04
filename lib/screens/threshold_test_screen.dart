import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../audio_engine/audio_engine.dart';
import '../models/audiogram.dart';

class ThresholdTestScreen extends StatefulWidget {
  const ThresholdTestScreen({super.key});

  @override
  State<ThresholdTestScreen> createState() => _ThresholdTestScreenState();
}

class _ThresholdTestScreenState extends State<ThresholdTestScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final List<int> _frequencies = [1000, 2000, 4000, 8000, 500, 250];

  EarSide _currentEar = EarSide.left;
  int _currentFreqIndex = 0;
  double _currentDb = 40.0;
  bool _isTesting = false;
  bool _testFinished = false;

  // Hughson-Westlake: lista de reversões por frequência atual
  final List<double> _reversals = [];
  bool? _lastResponse; // null = primeira resposta
  static const int _requiredReversals = 3;

  // Resultados por orelha
  final List<AudiometryPoint> _leftEarPoints = [];
  final List<AudiometryPoint> _rightEarPoints = [];

  @override
  void initState() {
    super.initState();
    _engine.initializeEngine(Audiogram(
      id: "TEMP_TEST",
      patientId: "TEMP_TEST",
      date: DateTime.now(),
      leftEar: [],
      rightEar: [],
    ));
  }

  void _startFrequencyTest() {
    setState(() {
      _isTesting = true;
      _testFinished = false;
      _currentDb = 40.0;
      _reversals.clear();
      _lastResponse = null;
    });
    _playCurrentTestTone();
  }

  void _playCurrentTestTone() {
    _engine.playPureTone(
      frequencyHz: _frequencies[_currentFreqIndex],
      durationMs: 1500,
      ear: _currentEar,
      dbLevel: _currentDb,
    );
  }

  // Protocolo Hughson-Westlake:
  //   Descida: 10 dB após "ouviu"
  //   Subida: 5 dB após "não ouviu"
  //   Limiar = média das últimas 3 reversões
  void _onResponse(bool detected) {
    if (!_isTesting) return;

    final bool? lastResp = _lastResponse;

    // Detecta reversão: mudança de direção na escada
    if (lastResp != null && detected != lastResp) {
      _reversals.add(_currentDb);
      if (_reversals.length >= _requiredReversals) {
        _recordThresholdAndNext();
        return;
      }
    }

    _lastResponse = detected;

    if (detected) {
      // Descida em 10 dB
      final next = _currentDb - 10.0;
      setState(() => _currentDb = next < -10.0 ? -10.0 : next);
    } else {
      // Subida em 5 dB
      final next = _currentDb + 5.0;
      setState(() => _currentDb = next > 120.0 ? 120.0 : next);
    }

    Future.delayed(const Duration(milliseconds: 300), _playCurrentTestTone);
  }

  void _recordThresholdAndNext() {
    // Média das _requiredReversals últimas reversões
    final recent = _reversals.length >= _requiredReversals
        ? _reversals.sublist(_reversals.length - _requiredReversals)
        : _reversals;
    final threshold = recent.reduce((a, b) => a + b) / recent.length;

    final point = AudiometryPoint(
      frequency: _frequencies[_currentFreqIndex],
      threshold: threshold.roundToDouble(),
    );

    if (_currentEar == EarSide.left) {
      _leftEarPoints.add(point);
    } else {
      _rightEarPoints.add(point);
    }

    _reversals.clear();
    _lastResponse = null;

    if (_currentFreqIndex < _frequencies.length - 1) {
      setState(() {
        _currentFreqIndex++;
        _currentDb = 40.0;
      });
      Future.delayed(const Duration(milliseconds: 800), _playCurrentTestTone);
    } else if (_currentEar == EarSide.left) {
      setState(() {
        _currentEar = EarSide.right;
        _currentFreqIndex = 0;
        _currentDb = 40.0;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _playCurrentTestTone();
      });
    } else {
      _finishTest();
    }
  }

  void _finishTest() {
    setState(() {
      _isTesting = false;
      _testFinished = true;
    });
  }

  static Widget _topTitleWidget(double value, TitleMeta meta) {
    // Frequências na ordem de teste: 1k, 2k, 4k, 8k, 500, 250
    const labels = ['1K', '2K', '4K', '8K', '500', '250'];
    final idx = value.toInt();
    if (idx >= 0 && idx < labels.length) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(labels[idx], style: const TextStyle(color: Colors.white54, fontSize: 10)),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "AUDIOMETRIA — LIMIAR TONAL",
          style: TextStyle(letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.5,
            colors: [Color(0xFF1E1E24), Color(0xFF0D0D0F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Frequência atual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Text(
                      "${_frequencies[_currentFreqIndex]} Hz",
                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: -2, color: Colors.white),
                    ),
                    Text(
                      _currentEar == EarSide.left ? "OUVIDO ESQUERDO" : "OUVIDO DIREITO",
                      style: TextStyle(
                        color: _currentEar == EarSide.left ? Colors.blueAccent : Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Intensidade: ${_currentDb.toInt()} dB HL",
                style: TextStyle(
                  color: Colors.redAccent.shade100,
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  shadows: [Shadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 20)],
                ),
              ),

              if (_isTesting) ...[
                const SizedBox(height: 16),
                Text(
                  "Reversões: ${_reversals.length} / $_requiredReversals",
                  style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],

              const SizedBox(height: 60),

              if (!_isTesting && !_testFinished) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Use fones de ouvido. O protocolo Hughson-Westlake vai subir e descer o volume até encontrar seu limiar exato em cada frequência.",
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 250,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _startFrequencyTest,
                    child: const Text("INICIAR PROTOCOLO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
              ] else if (_testFinished) ...[
                const Text("AUDIOGRAMA REGISTRADO", style: TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  height: 250,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LineChart(
                    LineChartData(
                      minY: -120,
                      maxY: 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(_leftEarPoints.length, (i) => FlSpot(i.toDouble(), -_leftEarPoints[i].threshold)),
                          isCurved: false,
                          color: Colors.blueAccent,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                        LineChartBarData(
                          spots: List.generate(_rightEarPoints.length, (i) => FlSpot(i.toDouble(), -_rightEarPoints[i].threshold)),
                          isCurved: false,
                          color: Colors.redAccent,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: _ThresholdTestScreenState._topTitleWidget,
                          ),
                        ),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 20,
                            getTitlesWidget: (v, _) => Text("${(-v).toInt()}dB", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 20, verticalInterval: 1),
                      borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.white10), left: BorderSide(color: Colors.white10))),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 250,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context, {
                      'left': _leftEarPoints,
                      'right': _rightEarPoints,
                    }),
                    child: const Text("SALVAR E CONTINUAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
              ] else ...[
                const Text("Você percebeu o estímulo sonoro?", style: TextStyle(fontSize: 18, color: Colors.white70)),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ResponseButton(label: "NÃO", color: const Color(0xFF1E1E24), textColor: Colors.white60, onPressed: () => _onResponse(false)),
                    const SizedBox(width: 40),
                    _ResponseButton(label: "SIM", color: const Color(0xFF2563EB), textColor: Colors.white, onPressed: () => _onResponse(true)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _ResponseButton({required this.label, required this.color, required this.textColor, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 25, spreadRadius: 1)],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: const CircleBorder(),
          elevation: 0,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }
}
