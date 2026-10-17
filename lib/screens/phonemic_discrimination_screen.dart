import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/audio_service_manager.dart';
import '../services/supabase_service.dart';
import '../training/adaptive_staircase.dart';
import '../training/item_selector.dart';
import '../training/progress_rules.dart';
import 'hearing_test/hearing_test_flow.dart';
import 'session_summary_screen.dart';
import 'widgets/phonemic_widgets.dart';
import 'widgets/training_app_bar.dart';
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

  static const _module = 'phonemic';
  int _currentTrial = 0; // tentativas respondidas
  int _correctAnswers = 0;
  // Sessão de ~10 min (a dose é em minutos acumulados, não em número de tentativas).
  final SessionClock _clock = SessionClock();
  bool _finished = false;

  Trial? _trial;
  Trial? _upcoming; // próxima tentativa, já baixada enquanto a pessoa responde a atual
  bool _canRespond = false;
  bool _isPlaying = false;
  TrialFeedback? _feedback; // retorno da última resposta (achado D3)
  String? _nowPlaying; // o que toca durante "Ouvir as duas"

  // Dificuldade: reforço extra só nas bandas agudas (>= 3 kHz); menos reforço = mais difícil.
  // Escada 3-acertos/1-erro (~79% de acerto), retomada de onde a pessoa parou.
  late final AdaptiveStaircase _boost = AdaptiveStaircase.resume(
      _gamification.trainingState(_module), start: 12, minValue: 0, maxValue: 24);
  double get _extraBoostDb => _boost.value;

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
    if (_selector.nothingAudible && mounted) await showInaudibleHighFrequencyWarning(context);
    _startTrial();
  }

  void _startTrial() {
    if (_clock.isOver) {
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

    _boost.record(correct: isCorrect);
    if (isCorrect) _correctAnswers++;
    isCorrect ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();

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
    _currentTrial++;

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
    if (_finished) return; // tempo esgotado e "Terminar" ao mesmo tempo
    _finished = true;
    final duration = _clock.elapsed.inMilliseconds;
    _gamification.saveTrainingState(_module, _boost.toJson());
    final session = RehabSession(
      patientId: _audiogram.patientId,
      date: DateTime.now(),
      level: RehabLevel.phonemicDiscrimination,
      totalTrials: _currentTrial,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: _currentTrial == 0 ? 0 : duration / _currentTrial,
      metadata: {
        'log': _sessionLog,
        'final_boost_db': _extraBoostDb,
        'boost_threshold_db': _boost.threshold,
        'staircase': '3-down-1-up',
        'stimulus_bank_version': 2,
        'duration_ms': duration,
      },
    );

    final reward = _gamification.completeSession(
      module: _module,
      threshold: _boost.threshold ?? _boost.value,
      duration: Duration(milliseconds: duration),
    );

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
    final level = ProgressRules.phonemicLevel(_boost.threshold ?? _extraBoostDb);
    SessionSummaryScreen.replaceCurrent(
      context,
      SessionSummary(
            training: 'Palavras parecidas',
            correct: _correctAnswers,
            total: _currentTrial,
            duration: Duration(milliseconds: duration),
            levelLine: 'Nível de dificuldade alcançado: $level de 7',
            reward: reward,
            minutesToday: _gamification.minutesToday,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _trial?.options ?? const <String>[];
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: TrainingAppBar(
        title: 'Palavras parecidas',
        canFinish: _currentTrial > 0 && !_isPlaying,
        onFinish: _finishSession,
        progress: _clock.progress,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Text(
                "Palavra ${_currentTrial + (_feedback == null ? 1 : 0)} · faltam cerca de ${_clock.minutesLeft} min",
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
