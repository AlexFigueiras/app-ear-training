import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/supabase_service.dart';

class PhonemicDiscriminationScreen extends StatefulWidget {
  final Audiogram audiogram;
  const PhonemicDiscriminationScreen({super.key, required this.audiogram});

  @override
  State<PhonemicDiscriminationScreen> createState() => _PhonemicDiscriminationScreenState();
}

class _PhonemicDiscriminationScreenState extends State<PhonemicDiscriminationScreen> {
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

  // Staircase 2-down/1-up: constrói dificuldade progressiva sem frustrar
  int _consecutiveCorrect = 0;
  double _extraBoostDb = 6.0; // Começa facilitado; reduz com acertos

  final List<Map<String, dynamic>> _sessionLog = [];

  @override
  void initState() {
    super.initState();
    _engine.initializeEngine(widget.audiogram);
    _gamification.resetEnergyForNewSession();
    _startTrial();
  }

  // Constrói audiogramData para seleção inteligente de fonemas
  List<Map<String, dynamic>> get _audiogramData => [
    ...widget.audiogram.leftEar.map((p) => {'frequency': p.frequency, 'threshold': p.threshold}),
    ...widget.audiogram.rightEar.map((p) => {'frequency': p.frequency, 'threshold': p.threshold}),
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

  Future<void> _playTarget() async {
    if (_currentPhoneme == null) return;
    await _engine.playPhonemicStimulus(
      text: _currentPhoneme!['target'] as String,
      freqBand: (_currentPhoneme!['freq_band'] as num).toDouble(),
      extraBoostDb: _extraBoostDb,
    );
    setState(() => _canRespond = true);
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
      patientId: widget.audiogram.patientId,
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
            const _PulseIcon(),
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
                  child: _AnimatedOptionCard(label: opt, onTap: () => _handleResponse(opt)),
                )).toList(),
              ),
            ),
            const SizedBox(height: 80),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey, size: 32),
              onPressed: _canRespond ? null : _playTarget,
              tooltip: "Repetir estímulo",
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon();

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueAccent.withValues(alpha: 0.05),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
        ),
        child: const Icon(Icons.hearing, size: 64, color: Colors.blueAccent),
      ),
    );
  }
}

class _AnimatedOptionCard extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AnimatedOptionCard({required this.label, required this.onTap});

  @override
  State<_AnimatedOptionCard> createState() => _AnimatedOptionCardState();
}

class _AnimatedOptionCardState extends State<_AnimatedOptionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 150,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
