import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/audio_service_manager.dart';
import '../services/supabase_service.dart';
import '../training/item_selector.dart';
import 'hearing_test/hearing_test_flow.dart';
import 'session_summary_screen.dart';
import 'widgets/phonemic_widgets.dart';
import 'widgets/trial_feedback.dart';

/// Treino "Palavras parecidas" (discriminação de pares mínimos).
class PhonemicDiscriminationScreen extends StatefulWidget {
  final Audiogram audiogram;
  const PhonemicDiscriminationScreen({super.key, required this.audiogram});

  @override
  State<PhonemicDiscriminationScreen> createState() => _PhonemicDiscriminationScreenState();
}

class _PhonemicDiscriminationScreenState extends State<PhonemicDiscriminationScreen> {
  late Audiogram _audiogram;
  late ItemSelector _selector;
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  final GamificationController _gamification = GamificationController();

  int _currentTrial = 0;
  // 25 tentativas por sessão (provisório: a dose passa a ser por tempo na Etapa 7 do plano)
  static const int _maxTrials = 25;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  Trial? _trial;
  Trial? _upcoming; // próxima tentativa, já baixada enquanto a pessoa responde a atual
  bool _canRespond = false;
  bool _isPlaying = false;
  TrialFeedback? _feedback; // retorno da última resposta (achado D3)
  String? _nowPlaying; // o que toca durante "Ouvir as duas"

  // Dificuldade: reforço extra só nas bandas agudas (>= 3 kHz). Provisório: escada 2-abaixo/
  // 1-acima; a escada definitiva (3-abaixo/1-acima, salva entre sessões) vem na Etapa 7.
  int _consecutiveCorrect = 0;
  double _extraBoostDb = 6.0;

  final List<Map<String, dynamic>> _sessionLog = [];

  @override
  void initState() {
    super.initState();
    _audiogram = widget.audiogram;
    _selector = ItemSelector(audiogram: _audiogram);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// Audiograma do teste antigo? Oferece refazer antes de treinar (o EQ e a escolha das
  /// palavras usam o audiograma).
  Future<void> _bootstrap() async {
    _audiogram = await HearingTestFlow.ensureCurrent(context, _audiogram);
    if (!mounted) return;
    _selector = ItemSelector(audiogram: _audiogram);
    await _engine.initializeEngine(_audiogram);
    if (_selector.nothingAudible && mounted) await _warnInaudible();
    _startTrial();
  }

  /// Guarda de audibilidade: nenhuma pista aguda chega ao ouvido nem no máximo.
  Future<void> _warnInaudible() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Os sons agudos estão fora do alcance'),
          content: const Text(
            'Pelo seu teste, os sons agudos das palavras (como o "s") não chegam ao seu ouvido nem '
            'no volume máximo. Treinar não consegue criar essa percepção. Procure um '
            'fonoaudiólogo: um aparelho auditivo pode trazer esses sons de volta. '
            'Por enquanto, o treino vai usar só palavras com sons mais graves.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
        ),
      );

  void _startTrial() {
    if (_currentTrial >= _maxTrials) {
      _finishSession();
      return;
    }
    _trial = _upcoming ?? _selector.next();
    _upcoming = _selector.next();
    _engine.prefetchSpeech(_upcoming!.played, voice: _upcoming!.voice);
    setState(() => _canRespond = false);
    _playTarget();
  }

  /// Toca a palavra e só libera a resposta quando ela termina.
  Future<void> _playTarget() async {
    final trial = _trial;
    if (trial == null || _isPlaying) return;
    setState(() {
      _isPlaying = true;
      _canRespond = false;
    });
    try {
      final duration = await _engine.playPhonemicStimulus(
        text: trial.played,
        voice: trial.voice,
        freqBand: trial.pair.contrast.cueBandHz.toDouble(),
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
    final trial = _trial;
    if (!_canRespond || trial == null) return;

    final isCorrect = trial.isCorrect(selected);
    final presentedBoost = _extraBoostDb;
    _selector.record(trial, correct: isCorrect);

    if (isCorrect) {
      _correctAnswers++;
      _consecutiveCorrect++;
      if (_consecutiveCorrect >= 2) {
        _consecutiveCorrect = 0;
        _extraBoostDb = (_extraBoostDb - 3.0).clamp(0.0, 18.0); // mais difícil
      }
      HapticFeedback.lightImpact();
    } else {
      _consecutiveCorrect = 0;
      _extraBoostDb = (_extraBoostDb + 3.0).clamp(0.0, 18.0); // mais fácil
      HapticFeedback.heavyImpact();
    }

    _sessionLog.add({
      'trial': _currentTrial + 1,
      'pair': trial.pair.id,
      'contrast': trial.pair.contrast.name,
      'cue_band_hz': trial.pair.contrast.cueBandHz,
      'played': trial.played,
      'voice': trial.voice,
      'selected': selected,
      'correct': isCorrect,
      'boost_db': presentedBoost,
    });

    setState(() {
      _canRespond = false;
      _feedback = TrialFeedback(correct: isCorrect, correctAnswer: trial.played, selected: selected);
    });
    // Acerto: avança sozinho. Erro: espera "Continuar", para dar tempo de comparar.
    if (isCorrect) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted && _feedback != null) _advance();
      });
    }
  }

  void _advance() {
    setState(() {
      _feedback = null;
      _nowPlaying = null;
      _currentTrial++;
    });
    _startTrial();
  }

  /// Feedback contrastivo: toca a certa e depois a que a pessoa marcou, na mesma voz.
  Future<void> _listenBoth() async {
    final trial = _trial;
    final feedback = _feedback;
    if (trial == null || feedback == null || _isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      for (final (label, word) in [('Certa', trial.played), ('Marcada', feedback.selected)]) {
        if (!mounted) return;
        setState(() => _nowPlaying = '$label: "$word"');
        final duration = await _engine.playPhonemicStimulus(
          text: word,
          voice: trial.voice,
          freqBand: trial.pair.contrast.cueBandHz.toDouble(),
          extraBoostDb: _extraBoostDb,
        );
        await Future.delayed(duration + const Duration(milliseconds: 500));
      }
    } catch (_) {
      // Sem rede: o retorno visual continua valendo.
    }
    if (mounted) setState(() => _isPlaying = false);
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
        'stimulus_bank_version': 2,
      },
    );

    final contrasts = _sessionLog.map((e) => e['contrast'] as String).toList();
    _gamification.addAcuityXP(session.accuracy / 100.0, contrasts);
    _gamification.incrementSessionsToday();

    try {
      await _supabase.saveRehabSession(session);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _supabase.saveGamificationData(_gamification.toMapForSupabase());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar sessão: $e")));
      }
    }
    if (!mounted) return;
    // Nível de dificuldade em linguagem comum: reforço 18 dB = nível 1 ... 0 dB = nível 7.
    final level = 1 + ((18 - _extraBoostDb) / 3).round();
    SessionSummaryScreen.replaceCurrent(
      context,
      SessionSummary(
            training: 'Palavras parecidas',
            correct: _correctAnswers,
            total: _maxTrials,
            duration: Duration(milliseconds: duration),
            levelLine: 'Nível de dificuldade alcançado: $level de 7',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _trial?.options ?? const <String>[];
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Palavras parecidas", style: TextStyle(fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _currentTrial / _maxTrials,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Text(
                "Palavra ${(_currentTrial + 1).clamp(1, _maxTrials)} de $_maxTrials",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              const PulseIcon(),
              const SizedBox(height: 40),
              const Text(
                "Qual palavra você ouviu?",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 48),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Wrap(
                  key: ValueKey(_currentTrial),
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    for (final opt in options)
                      AnimatedOptionCard(label: opt, onTap: () => _handleResponse(opt), highlight: feedbackHighlight(_feedback, opt)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_feedback != null)
                FeedbackBanner(
                  feedback: _feedback!,
                  nowPlaying: _nowPlaying,
                  onListenBoth: _feedback!.correct ? null : _listenBoth,
                  onContinue: _feedback!.correct || _isPlaying ? null : _advance,
                ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _isPlaying ? null : _playTarget,
                icon: const Icon(Icons.refresh, size: 28),
                label: const Text("Ouvir de novo", style: TextStyle(fontSize: 18)),
                style: TextButton.styleFrom(foregroundColor: Colors.white70, minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
