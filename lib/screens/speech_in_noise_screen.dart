import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/audio_service_manager.dart';
import '../training/item_selector.dart';
import 'hearing_test/hearing_test_flow.dart';
import '../services/supabase_service.dart';

class SpeechInNoiseScreen extends StatefulWidget {
  final Audiogram audiogram;
  const SpeechInNoiseScreen({super.key, required this.audiogram});

  @override
  State<SpeechInNoiseScreen> createState() => _SpeechInNoiseScreenState();
}

class _SpeechInNoiseScreenState extends State<SpeechInNoiseScreen> {
  late Audiogram _audiogram;
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  final GamificationController _gamification = GamificationController();

  double _currentSnr = 15.0; // Inicia facilitado (+15 dB SNR)
  int _currentTrial = 0;
  // 20 tentativas por sessão (provisório: a dose passa a ser por tempo na Etapa 7 do plano)
  static const int _maxTrials = 20;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  // Palavras do banco novo (qualquer uma do par pode tocar). Sem aquecimento: no ruído, só
  // contrastes agudos.
  late ItemSelector _selector;
  Trial? _trial;
  List<String> get _options => _trial?.options ?? const [];
  bool _canRespond = false;
  bool _isPlaying = false;

  static const List<String> _noiseEnvironments = ['RESTAURANTE', 'TRÁFEGO', 'VENTO'];
  String _currentEnvironment = 'RESTAURANTE';

  final List<Map<String, dynamic>> _sessionLog = [];

  @override
  void initState() {
    super.initState();
    _audiogram = widget.audiogram;
    _selector = ItemSelector(audiogram: _audiogram, warmUpTrials: 0);
    _gamification.resetEnergyForNewSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// Audiograma do teste antigo? Oferece refazer antes de treinar (o EQ usa o audiograma).
  Future<void> _bootstrap() async {
    _audiogram = await HearingTestFlow.ensureCurrent(context, _audiogram);
    if (!mounted) return;
    _selector = ItemSelector(audiogram: _audiogram, warmUpTrials: 0);
    await _engine.initializeEngine(_audiogram);
    _startTrial();
  }

  void _startTrial() {
    if (_currentTrial >= _maxTrials) {
      _finishSession();
      return;
    }

    // Fonema priorizado pela zona de perda do paciente
    _trial = _selector.next();
    _currentEnvironment = _noiseEnvironments[Random().nextInt(3)];

    setState(() => _canRespond = false);
    _playStimulus();
  }

  /// Toca a palavra no ruído e só libera a resposta quando ela termina.
  Future<void> _playStimulus() async {
    final trial = _trial;
    if (trial == null || _isPlaying) return;
    setState(() {
      _isPlaying = true;
      _canRespond = false;
    });
    try {
      final duration = await _engine.playCocktailStimulus(
        text: trial.played,
        voice: trial.voice,
        snrDb: _currentSnr,
        noiseEnvironment: _currentEnvironment,
        freqBand: trial.pair.contrast.cueBandHz.toDouble(),
      );
      await Future.delayed(duration);
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _canRespond = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Não foi possível tocar a palavra. Verifique a internet e toque em Repetir.")));
    }
  }

  @override
  void dispose() {
    // Desliga o ruído: antes ele continuava tocando para sempre depois da sessão.
    AudioServiceManager().silenceAll();
    super.dispose();
  }

  void _handleResponse(String selected) {
    final trial = _trial;
    if (!_canRespond || trial == null) return;

    // SNR em que a palavra foi de fato apresentada (o log antigo gravava o valor já atualizado).
    final presentedSnr = _currentSnr;
    final isCorrect = trial.isCorrect(selected);
    _selector.record(trial, correct: isCorrect);
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
      'pair': trial.pair.id,
      'contrast': trial.pair.contrast.name,
      'played': trial.played,
      'voice': trial.voice,
      'selected': selected,
      'snr_presented': presentedSnr,
      'environment': _currentEnvironment,
      'correct': isCorrect,
    });

    setState(() => _currentTrial++);
    _startTrial();
  }

  void _finishSession() async {
    AudioServiceManager().silenceAll(); // o ruído para já, não só ao sair da tela
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
    final session = RehabSession(
      patientId: _audiogram.patientId,
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
              "Palavra ${(_currentTrial + 1).clamp(1, _maxTrials)} de $_maxTrials",
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
              onPressed: _isPlaying ? null : _playStimulus,
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
