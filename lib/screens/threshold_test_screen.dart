import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio_engine/audio_engine.dart';
import '../models/audiogram.dart';
import '../services/audio_output_service.dart';
import '../training/hearing_test_session.dart';
import 'hearing_test/hearing_test_intro_view.dart';
import 'hearing_test/hearing_test_result_view.dart';
import 'hearing_test/test_panels.dart';

enum _Phase { intro, practice, earIntro, testing, result }

/// Teste auditivo (Etapa 4 do plano; achados C1–C4 da auditoria de UX).
///
/// Fluxo: instruções → tom de treino → aviso do ouvido → bipes com "Ouvi"/"Não ouvi" → resultado.
/// A lógica clínica fica em [HearingTestSession]/[ThresholdProcedure] (Dart puro, testada); esta
/// tela só apresenta. Devolve `{'left': List<AudiometryPoint>, 'right': List<AudiometryPoint>}`
/// ao salvar (mesmo contrato usado pela Home e pelo onboarding).
class ThresholdTestScreen extends StatefulWidget {
  const ThresholdTestScreen({super.key});

  @override
  State<ThresholdTestScreen> createState() => _ThresholdTestScreenState();
}

class _ThresholdTestScreenState extends State<ThresholdTestScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final AudioOutputService _output = const AudioOutputService();
  final math.Random _random = math.Random();

  _Phase _phase = _Phase.intro;
  HearingTestSession _session = HearingTestSession();
  OutputRoute _route = OutputRoute.unknown;
  bool _quietConfirmed = false;
  MediaVolume? _volume;
  bool _playing = false;
  bool _awaitingAnswer = false;
  String? _notice;
  Audiogram? _audiogram;

  @override
  void initState() {
    super.initState();
    _engine.initializeEngine(Audiogram(id: '', patientId: '', date: DateTime.now(), leftEar: [], rightEar: []));
    _checkRoute();
  }

  @override
  void dispose() {
    _engine.silenceAll(); // não deixa um bipe tocando ao sair no meio do teste
    super.dispose();
  }

  Future<void> _checkRoute() async {
    final route = await _output.outputRoute();
    if (mounted) setState(() => _route = route);
  }

  Future<void> _startPractice() async {
    _volume = await _output.mediaVolume();
    setState(() {
      _phase = _Phase.practice;
      _notice = null;
    });
    await _play(() => _engine.playPureTone(
        frequencyHz: 1000, durationMs: 0, ear: EarSide.both, dbLevel: 50, pulsed: true));
  }

  void _practiceAnswer(bool heard) {
    if (heard) {
      setState(() {
        _phase = _Phase.earIntro;
        _notice = null;
      });
    } else {
      setState(() => _notice = 'Confira se o fone está bem colocado e aumente um pouco o volume. '
          'Depois toque em "Tocar de novo".');
    }
  }

  Future<void> _play(Future<Duration> Function() action) async {
    setState(() {
      _playing = true;
      _awaitingAnswer = false;
    });
    final duration = await action();
    await Future.delayed(duration);
    if (!mounted) return;
    setState(() {
      _playing = false;
      _awaitingAnswer = true;
    });
  }

  /// Volume mudou desde o início? O nível relativo só vale com o volume fixo.
  Future<bool> _volumeUnchanged() async {
    final now = await _output.mediaVolume();
    if (_volume == null || now == null || now == _volume) return true;
    if (!mounted) return false;
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('O volume mudou'),
        content: Text('O volume do celular estava em ${_volume!.current} e agora está em ${now.current}. '
            'Para o resultado valer, volte para ${_volume!.current} e toque em "Continuar".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Recomeçar o teste')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (keep == true) return _volumeUnchanged();
    _restart();
    return false;
  }

  Future<void> _present() async {
    if (!await _volumeUnchanged() || !mounted) return;
    final step = _session.currentStep;
    final p = _session.next();
    if (p.isCatch) {
      await _play(() async => AudioRehabEngine.pulsedToneDuration);
    } else {
      await _play(() => _engine.playPureTone(
          frequencyHz: step.frequency, durationMs: 0, ear: step.ear, dbLevel: p.level, pulsed: true));
    }
  }

  Future<void> _answer(bool heard) async {
    if (!_awaitingAnswer) return;
    setState(() => _awaitingAnswer = false);
    final procedure = _session.procedure;
    _session.respond(heard);
    setState(() => _notice = procedure.restartedForFalseAlarms
        ? 'Toque em "Ouvi" só quando tiver certeza de que ouviu o bipe. Vamos repetir esta parte.'
        : null);
    if (_session.isDone) {
      setState(() {
        _audiogram = Audiogram(
          id: '',
          patientId: '',
          date: DateTime.now(),
          leftEar: _session.pointsFor(EarSide.left),
          rightEar: _session.pointsFor(EarSide.right),
        );
        _phase = _Phase.result;
      });
      return;
    }
    if (_session.atEarStart) {
      setState(() => _phase = _Phase.earIntro);
      return;
    }
    // Intervalo irregular: sem ritmo previsível, a pessoa não "adivinha" o próximo bipe.
    await Future.delayed(Duration(milliseconds: 700 + _random.nextInt(900)));
    if (mounted && _phase == _Phase.testing) await _present();
  }

  void _restart() {
    _engine.silenceAll();
    setState(() {
      _session = HearingTestSession();
      _phase = _Phase.intro;
      _notice = null;
      _audiogram = null;
      _playing = false;
      _awaitingAnswer = false;
    });
  }

  void _save() {
    final a = _audiogram!;
    Navigator.pop(context, {'left': a.leftEar, 'right': a.rightEar});
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do teste?'),
        content: const Text('O que você já respondeu será perdido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar o teste')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = _phase != _Phase.intro && _phase != _Phase.result;
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Teste de audição', style: TextStyle(fontSize: 18)),
        ),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.intro:
        return HearingTestIntroView(
          route: _route,
          quietConfirmed: _quietConfirmed,
          onQuietChanged: (v) => setState(() => _quietConfirmed = v),
          onRecheckRoute: _checkRoute,
          onStart: _startPractice,
        );
      case _Phase.practice:
        return AnswerPanel(
          heading: 'Som de treino',
          instruction: 'Este é o som que você vai procurar. Você ouviu os bipes?',
          playing: _playing,
          canAnswer: _awaitingAnswer,
          notice: _notice,
          onAnswer: _practiceAnswer,
          onReplay: _playing ? null : _startPractice,
        );
      case _Phase.earIntro:
        final left = _session.currentStep.ear == EarSide.left;
        return EarIntroPanel(
          ear: left ? 'esquerdo' : 'direito',
          onContinue: () {
            setState(() => _phase = _Phase.testing);
            _present();
          },
        );
      case _Phase.testing:
        final step = _session.currentStep;
        return AnswerPanel(
          heading: 'Ouvido ${step.ear == EarSide.left ? 'esquerdo' : 'direito'}',
          instruction: _playing ? 'Escute com atenção…' : 'Você ouviu os bipes?',
          progress: _session.progress,
          playing: _playing,
          canAnswer: _awaitingAnswer,
          notice: _notice,
          onAnswer: _answer,
        );
      case _Phase.result:
        return HearingTestResultView(audiogram: _audiogram!, onSave: _save, onRetest: _restart);
    }
  }
}

