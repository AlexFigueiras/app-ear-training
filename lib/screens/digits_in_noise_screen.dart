import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../audio_engine/audio_engine.dart';
import '../audio_engine/masker_bank.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/audio_service_manager.dart';
import '../services/supabase_service.dart';
import '../training/digits_in_noise.dart';
import '../ui/theme/bosyn_text.dart';
import 'session_summary_screen.dart';
import 'widgets/digit_keypad.dart';

enum _Phase { intro, preparing, listening, answering }

/// "Medir minha audição na fala": teste de dígitos no ruído (Etapa 8 do plano; achado E1).
/// Medida de progresso a cada 14 dias, com material que o treino não usa. Sem retorno por
/// tentativa (é medida, não treino).
class DigitsInNoiseScreen extends StatefulWidget {
  final Audiogram? audiogram;

  const DigitsInNoiseScreen({super.key, this.audiogram});

  @override
  State<DigitsInNoiseScreen> createState() => _DigitsInNoiseScreenState();
}

class _DigitsInNoiseScreenState extends State<DigitsInNoiseScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final DinProcedure _din = DinProcedure();
  final List<Map<String, dynamic>> _log = [];
  final DateTime _start = DateTime.now();
  _Phase _phase = _Phase.intro;
  DigitTriplet? _triplet;
  List<int> _entered = [];

  @override
  void dispose() {
    AudioServiceManager().silenceAll();
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() => _phase = _Phase.preparing);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await _engine.initializeEngine(widget.audiogram ??
          Audiogram(id: '', patientId: user?.id ?? '', date: DateTime.now(), leftEar: [], rightEar: []));
      await _engine.prepareDigits();
      await _engine.startMasker(MaskerType.speechShaped);
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.intro);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível preparar o teste. Verifique a internet e tente de novo.')));
      return;
    }
    _next();
  }

  Future<void> _next() async {
    if (_din.isDone) return _finish();
    final triplet = _din.next();
    setState(() {
      _triplet = triplet;
      _entered = [];
      _phase = _Phase.listening;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    final duration = await _engine.playDigitTriplet(triplet.digits, triplet.snrDb);
    await Future.delayed(duration);
    if (mounted) setState(() => _phase = _Phase.answering);
  }

  void _confirm() {
    final triplet = _triplet!;
    final correct = _din.respond(_entered);
    _log.add({'digits': triplet.digits, 'answer': _entered, 'snr': triplet.snrDb, 'correct': correct});
    _next();
  }

  Future<void> _finish() async {
    AudioServiceManager().silenceAll();
    final srt = _din.srt!;
    final user = Supabase.instance.client.auth.currentUser;
    final session = RehabSession(
      patientId: user?.id ?? '',
      date: DateTime.now(),
      level: RehabLevel.digitsInNoise,
      totalTrials: DinProcedure.totalTriplets,
      correctAnswers: _din.correctTriplets,
      averageResponseTimeMs: 0,
      metadata: {
        'measure': 'din_internal_v1',
        'srt_db': srt,
        'voice': AudioRehabEngine.dinVoice,
        'masker': MaskerType.speechShaped.name,
        'log': _log,
      },
    );
    try {
      await SupabaseService().saveRehabSession(session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar o resultado: $e')));
      }
    }
    if (!mounted) return;
    SessionSummaryScreen.replaceCurrent(
      context,
      SessionSummary(
        training: 'Audição na fala',
        correct: _din.correctTriplets,
        total: DinProcedure.totalTriplets,
        duration: DateTime.now().difference(_start),
        levelLine: '${DinProcedure.describe(srt)} Medida interna do app, não é exame. '
            'Repita daqui a 14 dias para ver a evolução.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Audição na fala', style: TextStyle(fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _din.index / DinProcedure.totalTriplets, backgroundColor: Colors.white10),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _phase == _Phase.intro ? _intro() : _test(),
        ),
      ),
    );
  }

  Widget _intro() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Medir minha audição na fala', style: BosynText.title),
        const SizedBox(height: 16),
        const Text(
          'Você vai ouvir 3 números no meio de um ruído (por exemplo: "quatro, sete, dois") e '
          'digitar os 3. Se não tiver certeza, chute. São 24 vezes, uns 4 minutos.',
          style: BosynText.body,
        ),
        const SizedBox(height: 12),
        const Text(
          'Use fone de ouvido num lugar silencioso, com o mesmo volume de sempre. Faça a cada 14 '
          'dias: é assim que dá para ver se a sua compreensão no barulho está melhorando.',
          style: BosynText.bodySecondary,
        ),
        const SizedBox(height: 12),
        const Text('Medida interna do app, não validada clinicamente. Não é um exame.',
            style: BosynText.caption),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _begin,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Começar', style: BosynText.button),
          ),
        ),
      ]);

  Widget _test() => Column(children: [
        Text(
          _phase == _Phase.preparing
              ? 'Preparando…'
              : 'Trio ${_din.index + 1} de ${DinProcedure.totalTriplets}',
          style: BosynText.heading,
        ),
        const SizedBox(height: 8),
        Text(
          _phase == _Phase.answering ? 'Digite os 3 números que ouviu.' : 'Escute…',
          style: BosynText.body,
        ),
        const SizedBox(height: 24),
        DigitKeypad(
          entered: _entered,
          enabled: _phase == _Phase.answering,
          onDigit: (d) => setState(() => _entered = [..._entered, d]),
          onBackspace: () => setState(() => _entered = _entered.sublist(0, _entered.length - 1)),
          onConfirm: _confirm,
        ),
      ]);
}
