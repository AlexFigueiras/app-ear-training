import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/audio_service_manager.dart';
import 'hearing_test/hearing_test_flow.dart';
import 'widgets/phonemic_widgets.dart';
import '../services/supabase_service.dart';

class PhonemicDiscriminationScreen extends StatefulWidget {
  final Audiogram audiogram;
  const PhonemicDiscriminationScreen({super.key, required this.audiogram});

  @override
  State<PhonemicDiscriminationScreen> createState() => _PhonemicDiscriminationScreenState();
}

class _PhonemicDiscriminationScreenState extends State<PhonemicDiscriminationScreen> {
  late Audiogram _audiogram;
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  final GamificationController _gamification = GamificationController();

  int _currentTrial = 0;
  // 25 tentativas por sessão (provisório: a dose passa a ser por tempo na Etapa 7 do plano)
  static const int _maxTrials = 25;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  // Seleção atual a partir de phonemeRehabData (inclui freq_band)
  Map<String, dynamic>? _currentPhoneme;
  List<String> _options = [];
  bool _canRespond = false;
  bool _isPlaying = false;

  // Staircase 2-down/1-up: constrói dificuldade progressiva sem frustrar
  int _consecutiveCorrect = 0;
  double _extraBoostDb = 6.0; // Começa facilitado; reduz com acertos

  final List<Map<String, dynamic>> _sessionLog = [];

  @override
  void initState() {
    super.initState();
    _audiogram = widget.audiogram;
    _gamification.resetEnergyForNewSession();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// Audiograma do teste antigo? Oferece refazer antes de treinar (o EQ usa o audiograma).
  Future<void> _bootstrap() async {
    _audiogram = await HearingTestFlow.ensureCurrent(context, _audiogram);
    if (!mounted) return;
    await _engine.initializeEngine(_audiogram);
    _startTrial();
  }

  // Constrói audiogramData para seleção inteligente de fonemas
  List<Map<String, dynamic>> get _audiogramData => [
    ..._audiogram.leftEar.map((p) => {'frequency': p.frequency, 'threshold': p.threshold}),
    ..._audiogram.rightEar.map((p) => {'frequency': p.frequency, 'threshold': p.threshold}),
  ];

  void _startTrial() {
    if (_currentTrial >= _maxTrials) {
      _finishSession();
      return;
    }

    // Seleciona fonema priorizando a zona de perda do paciente
    _currentPhoneme = _gamification.getSmartPhoneme(_audiogramData);
    _options = [_currentPhoneme!['target'] as String, _currentPhoneme!['distractor'] as String]..shuffle();

    setState(() => _canRespond = false);
    _playTarget();
  }

  /// Toca a palavra e só libera a resposta quando ela termina (antes a resposta era liberada no
  /// instante em que o áudio era carregado, e a próxima tentativa cortava a palavra no meio).
  Future<void> _playTarget() async {
    if (_currentPhoneme == null || _isPlaying) return;
    setState(() {
      _isPlaying = true;
      _canRespond = false;
    });
    try {
      final duration = await _engine.playPhonemicStimulus(
        text: _currentPhoneme!['target'] as String,
        freqBand: (_currentPhoneme!['freq_band'] as num).toDouble(),
        extraBoostDb: _extraBoostDb,
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
    AudioServiceManager().silenceAll();
    super.dispose();
  }

  void _handleResponse(String selected) {
    if (!_canRespond || _currentPhoneme == null) return;

    final isCorrect = selected == _currentPhoneme!['target'];

    // Staircase 2-down/1-up
    if (isCorrect) {
      _correctAnswers++;
      _consecutiveCorrect++;
      if (_consecutiveCorrect >= 2) {
        _consecutiveCorrect = 0;
        _extraBoostDb = (_extraBoostDb - 3.0).clamp(0.0, 18.0); // Mais difícil
      }
      HapticFeedback.lightImpact();
    } else {
      _consecutiveCorrect = 0;
      _extraBoostDb = (_extraBoostDb + 3.0).clamp(0.0, 18.0); // Mais fácil
      _gamification.consumeEnergy();
      HapticFeedback.heavyImpact();
    }

    _sessionLog.add({
      'trial': _currentTrial + 1,
      'target': _currentPhoneme!['target'],
      'distractor': _currentPhoneme!['distractor'],
      'freq_band': _currentPhoneme!['freq_band'],
      'type': _currentPhoneme!['type'],
      'selected': selected,
      'correct': isCorrect,
      'boost_db': _extraBoostDb,
    });

    setState(() => _currentTrial++);
    _startTrial();
  }

  void _finishSession() async {
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
    final session = RehabSession(
      patientId: _audiogram.patientId,
      date: DateTime.now(),
      level: RehabLevel.phonemicDiscrimination,
      totalTrials: _maxTrials,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: duration / _maxTrials,
      metadata: {
        'log': _sessionLog,
        'final_boost_db': _extraBoostDb,
        'critical_phoneme_band': _currentPhoneme?['freq_band'],
      },
    );

    // Atualiza gamificação com desempenho da sessão
    final phonemeTypes = _sessionLog
        .map((e) => e['type'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    _gamification.addAcuityXP(session.accuracy / 100.0, phonemeTypes);
    _gamification.incrementSessionsToday();

    try {
      await _supabase.saveRehabSession(session);
      // Persiste estado de gamificação para carregar na próxima sessão
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
        backgroundColor: Colors.transparent,
        title: const Text("NÍVEL 2: DISCRIMINAÇÃO FONÊMICA"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "BOOST: ${_extraBoostDb.toStringAsFixed(0)} dB",
                style: TextStyle(
                  color: _extraBoostDb > 9 ? Colors.orange : Colors.greenAccent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _currentTrial / _maxTrials,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Trial ${_currentTrial + 1} / $_maxTrials",
              style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 24),
            const PulseIcon(),
            const SizedBox(height: 48),
            const Text(
              "Qual palavra você ouviu?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 64),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Row(
                key: ValueKey(_currentTrial),
                mainAxisAlignment: MainAxisAlignment.center,
                children: _options.map((opt) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AnimatedOptionCard(label: opt, onTap: () => _handleResponse(opt)),
                )).toList(),
              ),
            ),
            const SizedBox(height: 80),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey, size: 32),
              onPressed: _isPlaying ? null : _playTarget,
              tooltip: "Repetir estímulo",
            ),
          ],
        ),
      ),
    );
  }
}

