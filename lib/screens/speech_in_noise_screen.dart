import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../audio_engine/masker_bank.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/audio_service_manager.dart';
import '../services/supabase_service.dart';
import '../training/adaptive_staircase.dart';
import '../training/item_selector.dart';
import 'hearing_test/hearing_test_flow.dart';
import 'session_summary_screen.dart';
import 'widgets/choice_grid.dart';
import 'widgets/noise_level_header.dart';
import 'widgets/trial_feedback.dart';

/// Treino "Conversa no barulho" (fala no ruído), Etapa 7 do plano:
/// - ruído contínuo com espectro de fala ou burburinho de 6 vozes, com SNR exato;
/// - 4 opções {sala, fala, salas, falas} (chance de 25%) e frase-veículo "Diga ___ agora";
/// - escada 3-acertos/1-erro no SNR (~79% de acerto), retomada de onde parou;
/// - sessão de ~10 minutos, sem punição por erro.
/// Variantes do treino no ruído.
enum NoiseTraining {
  /// Fala e ruído do mesmo lugar.
  cocktail('cocktail', 'Conversa no barulho', RehabLevel.speechInNoise, 10),

  /// Etapa 9: a voz vem de um lado (±60°) e o burburinho do outro. Treina usar a posição para
  /// separar a voz do barulho (liberação espacial do mascaramento), em vez do antigo "de que
  /// lado veio", que tocava num ouvido só e qualquer pessoa acertava.
  spatial('spatial', 'Voz de um lado, barulho do outro', RehabLevel.spatialAttention, 5);

  final String module;
  final String title;
  final RehabLevel level;
  final double startSnr;

  const NoiseTraining(this.module, this.title, this.level, this.startSnr);
}

class SpeechInNoiseScreen extends StatefulWidget {
  final Audiogram audiogram;
  final NoiseTraining training;
  const SpeechInNoiseScreen({super.key, required this.audiogram, this.training = NoiseTraining.cocktail});

  @override
  State<SpeechInNoiseScreen> createState() => _SpeechInNoiseScreenState();
}

class _SpeechInNoiseScreenState extends State<SpeechInNoiseScreen> {
  NoiseTraining get _mode => widget.training;
  static const double _azimuth = 60;
  int _side = 1; // +1 = voz à direita, -1 = à esquerda (modo espacial)
  late Audiogram _audiogram;
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  final GamificationController _gamification = GamificationController();

  late AdaptiveStaircase _snr;
  final SessionClock _clock = SessionClock();
  late ItemSelector _selector;
  MaskerType? _masker; // null = ainda preparando o ruído
  Trial? _trial;
  int _trials = 0;
  int _correctAnswers = 0;
  bool _canRespond = false;
  bool _isPlaying = false;
  TrialFeedback? _feedback;
  String? _nowPlaying;
  final List<Map<String, dynamic>> _sessionLog = [];

  @override
  void initState() {
    super.initState();
    _audiogram = widget.audiogram;
    _selector = ItemSelector(audiogram: _audiogram, warmUpTrials: 0);
    _snr = AdaptiveStaircase.resume(_gamification.trainingState(_mode.module), start: _mode.startSnr, minValue: -15, maxValue: 20);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    _audiogram = await HearingTestFlow.ensureCurrent(context, _audiogram);
    if (!mounted) return;
    _selector = ItemSelector(audiogram: _audiogram, warmUpTrials: 0);
    await _engine.initializeEngine(_audiogram);
    // Burburinho (mais difícil: compete pela atenção) a partir do nível 5 de ruído.
    final wanted = _mode == NoiseTraining.spatial || NoiseLevelHeader.levelOf(_snr.value) >= 5
        ? MaskerType.babble
        : MaskerType.speechShaped;
    final used = await _engine.startMasker(wanted);
    if (!mounted) return;
    setState(() => _masker = used);
    _startTrial();
  }

  @override
  void dispose() {
    AudioServiceManager().silenceAll(); // desliga o ruído ao sair
    super.dispose();
  }

  static String _carrier(String word) => 'Diga $word agora.';

  void _startTrial() {
    if (_clock.isOver) {
      _finishSession();
      return;
    }
    _trial = _selector.nextQuad();
    _side = math.Random().nextBool() ? 1 : -1;
    setState(() => _canRespond = false);
    _playStimulus();
  }

  Future<void> _playWord(String word, Trial trial, double snrDb) async {
    final spatial = _mode == NoiseTraining.spatial;
    final duration = await _engine.playCocktailStimulus(
      text: _carrier(word),
      voice: trial.voice,
      snrDb: snrDb,
      azimuthDeg: spatial ? _side * _azimuth : null,
      maskerAzimuthDeg: spatial ? -_side * _azimuth : null,
      freqBand: trial.pair.contrast.cueBandHz.toDouble(),
    );
    await Future.delayed(duration);
  }

  Future<void> _playStimulus() async {
    final trial = _trial;
    if (trial == null || _isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      await _playWord(trial.played, trial, _snr.value);
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _canRespond = _feedback == null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Não foi possível tocar a frase. Verifique a internet e toque em Ouvir de novo.")));
    }
  }

  void _handleResponse(String selected) {
    final trial = _trial;
    if (!_canRespond || trial == null) return;
    final presentedSnr = _snr.value;
    final isCorrect = trial.isCorrect(selected);
    _selector.record(trial, correct: isCorrect);
    _snr.record(correct: isCorrect);
    _trials++;
    if (isCorrect) _correctAnswers++;
    isCorrect ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();

    _sessionLog.add({
      'trial': _trials,
      'pair': trial.pair.id,
      'contrast': trial.pair.contrast.name,
      'options': trial.options,
      'played': trial.played,
      'voice': trial.voice,
      'selected': selected,
      'snr_presented': presentedSnr,
      'masker': _masker?.name,
      if (_mode == NoiseTraining.spatial) 'voice_azimuth_deg': _side * _azimuth,
      'correct': isCorrect,
    });

    setState(() {
      _canRespond = false;
      _feedback = TrialFeedback(correct: isCorrect, correctAnswer: trial.played, selected: selected);
    });
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

  /// Feedback contrastivo: a certa e a marcada, na mesma voz e no mesmo ruído.
  Future<void> _listenBoth() async {
    final trial = _trial;
    final feedback = _feedback;
    if (trial == null || feedback == null || _isPlaying) return;
    setState(() => _isPlaying = true);
    final snr = _sessionLog.last['snr_presented'] as double;
    try {
      for (final (label, word) in [('Certa', trial.played), ('Marcada', feedback.selected)]) {
        if (!mounted) return;
        setState(() => _nowPlaying = '$label: "$word"');
        await _playWord(word, trial, snr);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {}
    if (mounted) setState(() => _isPlaying = false);
  }

  bool _finished = false;

  void _finishSession() async {
    if (_finished) return; // tempo esgotado e "Terminar" ao mesmo tempo
    _finished = true;
    AudioServiceManager().silenceAll(); // o ruído para já
    final duration = _clock.elapsed;
    _gamification.saveTrainingState(_mode.module, _snr.toJson());
    final session = RehabSession(
      patientId: _audiogram.patientId,
      date: DateTime.now(),
      level: _mode.level,
      totalTrials: _trials,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: _trials == 0 ? 0 : duration.inMilliseconds / _trials,
      metadata: {
        'log': _sessionLog,
        'final_snr': _snr.value,
        'snr_threshold': _snr.threshold,
        'masker': _masker?.name,
        'staircase': '3-down-1-up',
      },
    );
    _gamification.addAcuityXP(session.accuracy / 100.0, [_mode.module]);
    _gamification.incrementSessionsToday();

    try {
      await _supabase.saveRehabSession(session);
      if (Supabase.instance.client.auth.currentUser != null) {
        await _supabase.saveGamificationData(_gamification.toMapForSupabase());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar sessão: $e")));
      }
    }
    if (!mounted) return;
    final level = NoiseLevelHeader.levelOf(_snr.threshold ?? _snr.value);
    SessionSummaryScreen.replaceCurrent(
      context,
      SessionSummary(
        training: _mode.title,
        correct: _correctAnswers,
        total: _trials,
        duration: duration,
        levelLine: 'Nível de ruído alcançado: $level de 10',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preparing = _masker == null;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: Text(_mode.title, style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        actions: [
          if (_trials > 0)
            TextButton(
              onPressed: _isPlaying ? null : _finishSession,
              child: const Text('Terminar', style: TextStyle(fontSize: 16)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _clock.progress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            NoiseLevelHeader(snrDb: _snr.value),
            const SizedBox(height: 24),
            Text(
              preparing
                  ? 'Preparando o som de fundo…'
                  : 'Ouça a frase e escolha a palavra que veio depois de "Diga".',
              style: const TextStyle(fontSize: 18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (_mode == NoiseTraining.spatial && !preparing) ...[
              const SizedBox(height: 8),
              Text(
                'A voz vem da ${_side > 0 ? 'DIREITA' : 'ESQUERDA'}. O barulho vem do outro lado.',
                style: const TextStyle(fontSize: 18, color: Color(0xFF60A5FA), fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Text('Faltam cerca de ${_clock.minutesLeft} min',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            ChoiceGrid(
              options: _trial?.options ?? const [],
              enabled: _canRespond,
              feedback: _feedback,
              onChoose: _handleResponse,
            ),
            const SizedBox(height: 16),
            if (_feedback != null)
              FeedbackBanner(
                feedback: _feedback!,
                nowPlaying: _nowPlaying,
                onListenBoth: _feedback!.correct ? null : _listenBoth,
                onContinue: _feedback!.correct || _isPlaying ? null : _advance,
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isPlaying || preparing ? null : _playStimulus,
              icon: const Icon(Icons.refresh, size: 28),
              label: const Text("Ouvir de novo", style: TextStyle(fontSize: 18)),
              style: TextButton.styleFrom(foregroundColor: Colors.white70, minimumSize: const Size(48, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
