import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/audio_service_manager.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final List<int> _deltas = [];
  bool _isPlaying = false;
  Timer? _timer;
  int _lastBipAt = 0;
  double _systemicOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCurrentOffset();
  }

  Future<void> _loadCurrentOffset() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _systemicOffset = prefs.getDouble('systemic_offset_ms') ?? 0.0;
    });
  }

  void _startCalibration() {
    setState(() {
      _isPlaying = true;
      _deltas.clear();
    });

    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      _playBip();
    });
  }

  Future<void> _playBip() async {
    final engine = AudioServiceManager().engine;
    await engine.playCalibrationTone(durationSeconds: 0.05); // Bip curto de 50ms
    _lastBipAt = engine.getLastStimulusTimestampNs();
  }

  void _onTap() {
    if (!_isPlaying || _lastBipAt == 0) return;

    final engine = AudioServiceManager().engine;
    final now = engine.getNativeCurrentTimestampNs();
    
    // Delta bruto: Tempo entre o bip de hardware e o toque
    final deltaMs = (now - _lastBipAt) / 1000000.0;
    
    // Subtrai o tempo de reação humano ideal (200ms) para achar o delay do sistema
    // Se delta for 240ms e humano é 200ms, o sistema tem 40ms de lag real.
    final offset = deltaMs - 200.0;

    setState(() {
      _deltas.add(offset.toInt());
    });

    if (_deltas.length >= 10) {
      _finalizeCalibration();
    }
  }

  Future<void> _finalizeCalibration() async {
    _timer?.cancel();
    final avgOffset = _deltas.reduce((a, b) => a + b) / _deltas.length;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('systemic_offset_ms', avgOffset);

    setState(() {
      _isPlaying = false;
      _systemicOffset = avgOffset;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("CALIBRAÇÃO CONCLUÍDA: ${avgOffset.toStringAsFixed(1)}ms de Offset."))
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("CALIBRAÇÃO DE SINCRONIA", style: TextStyle(fontSize: 14, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Text(
              "AJUSTE DE LATÊNCIA SISTÊMICA",
              style: TextStyle(color: Color(0xFF00FF41), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Toque no botão central exatamente no momento em que ouvir o 'bip'. Repita 10 vezes para calcular o desvio médio do seu hardware.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Spacer(),
            
            GestureDetector(
              onTap: _onTap,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _isPlaying ? const Color(0xFF00FF41) : Colors.white10, width: 4),
                  boxShadow: _isPlaying ? [BoxShadow(color: const Color(0xFF00FF41).withValues(alpha: 0.2), blurRadius: 20)] : [],
                ),
                child: Center(
                  child: Text(
                    _isPlaying ? "${_deltas.length}/10" : "INICIAR",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            Container(
              padding: const EdgeInsets.all(24),
              color: const Color(0xFF1A1A1A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("OFFSET ATUAL:", style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text("${_systemicOffset.toStringAsFixed(1)} ms", style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'monospace')),
                ],
              ),
            ),
            
            if (!_isPlaying) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startCalibration,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text("RECALIBRAR"),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
