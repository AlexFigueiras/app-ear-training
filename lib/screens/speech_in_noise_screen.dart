import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/supabase_service.dart';

class SpeechInNoiseScreen extends StatefulWidget {
  final Audiogram audiogram;
  const SpeechInNoiseScreen({super.key, required this.audiogram});

  @override
  State<SpeechInNoiseScreen> createState() => _SpeechInNoiseScreenState();
}

class _SpeechInNoiseScreenState extends State<SpeechInNoiseScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  final GamificationController _gamification = GamificationController();

  double _currentSnr = 15.0; // Inicia facilitado (+15 dB SNR)
  int _currentTrial = 0;
  // Dose mínima efetiva para efeito de neuroplasticidade
  static const int _maxTrials = 20;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  Map<String, dynamic>? _currentPhoneme;
  List<String> _options = [];
  bool _canRespond = false;

  static const List<String> _noiseEnvironments = ['RESTAURANTE', 'TRÁFEGO', 'VENTO'];
  String _currentEnvironment = 'RESTAURANTE';

  final List<Map<String, dynamic>> _sessionLog = [];

  List<Map<String, dynamic>> get _audiogramData => [
    ...widget.audiogram.leftEar.map((p) => {'frequency': p.frequency, 'threshold': p.threshold}),
    ...widget.audiogram.rightEar.map((p) => {'frequency': p.frequency, 'threshold': p.threshold}),
  ];

  @override
  void initState() {
    super.initState();
    _engine.initializeEngine(widget.audiogram);
    _gamification.resetEnergyForNewSession();
    _startTrial();
  }

  void _startTrial() {
    if (_currentTrial >= _maxTrials) {
      _finishSession();
      return;
    }

    // Fonema priorizado pela zona de perda do paciente
    _currentPhoneme = _gamification.getSmartPhoneme(_audiogramData);
    _options = [_currentPhoneme!['target'] as String, _currentPhoneme!['distractor'] as String]..shuffle();
    _currentEnvironment = _noiseEnvironments[Random().nextInt(3)];

    setState(() => _canRespond = false);
    _playStimulus();
  }

  Future<void> _playStimulus() async {
    if (_currentPhoneme == null) return;
    await _engine.playCocktailStimulus(
      text: _currentPhoneme!['target'] as String,
      snrDb: _currentSnr,
      noiseEnvironment: _currentEnvironment,
      freqBand: (_currentPhoneme!['freq_band'] as num).toDouble(),
    );
    setState(() => _canRespond = true);
  }

  void _handleResponse(String selected) {
    if (!_canRespond || _currentPhoneme == null) return;

    final isCorrect = selected == _currentPhoneme!['target'];
    if (isCorrect) {
      _correctAnswers++;
      // Staircase: acerto → SNR mais baixo (mais ruído = mais difícil)
      _currentSnr = (_currentSnr - 2.0).clamp(-10.0, 20.0);
      HapticFeedback.lightImpact();
    } else {
      // Erro → facilita SNR para manter motivação e aprendizado
      _currentSnr = (_currentSnr + 2.0).clamp(-10.0, 20.0);
      _gamification.consumeEnergy();
      HapticFeedback.heavyImpact();
    }

    _sessionLog.add({
      'trial': _currentTrial + 1,
      'target': _currentPhoneme!['target'],
      'freq_band': _currentPhoneme!['freq_band'],
      'snr_at_response': _currentSnr,
      'environment': _currentEnvironment,
      'correct': isCorrect,
    });

    setState(() => _currentTrial++);
    _startTrial();
  }

  void _finishSession() async {
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
    final session = RehabSession(
      patientId: widget.audiogram.patientId,
      date: DateTime.now(),
      level: RehabLevel.speechInNoise,
      totalTrials: _maxTrials,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: duration / _maxTrials,
      metadata: {
        'log': _sessionLog,
        'final_snr': _currentSnr,
      },
    );

    // Gamificação: sinalizar fonemas cocktail para automação de SNR
    _gamification.addAcuityXP(session.accuracy / 100.0, ['cocktail']);
    _gamification.incrementSessionsToday();

    try {
      await _supabase.saveRehabSession(session);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _supabase.saveGamificationData(_gamification.toMapForSupabase());
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar sessão: $e")));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: const Text("NÍVEL 4: EFEITO COQUETEL"),
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _currentTrial / _maxTrials,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SNR ADAPTATIVO", style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                      Text(
                        _currentEnvironment,
                        style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1),
                      ),
                    ],
                  ),
                  Text(
                    "${_currentSnr.toInt()} dB",
                    style: TextStyle(
                      color: _currentSnr < 5 ? Colors.orange : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Icon(Icons.forum, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 32),
            const Text("Compreensão em Ruído", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Identifique a palavra no meio do som ambiente",
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              "Trial ${_currentTrial + 1} / $_maxTrials",
              style: const TextStyle(color: Colors.white24, fontSize: 11, fontFamily: 'monospace'),
            ),
            const Spacer(),
            Row(
              children: _options.map((opt) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E24),
                      minimumSize: const Size(0, 100),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _canRespond ? () => _handleResponse(opt) : null,
                    child: Text(opt, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _canRespond ? null : _playStimulus,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Repetir", style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: Colors.white38),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
