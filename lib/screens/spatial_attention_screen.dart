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
import 'session_summary_screen.dart';
import 'widgets/trial_feedback.dart';
import '../services/supabase_service.dart';

enum SpatialDirection { left, center, right }

class SpatialAttentionScreen extends StatefulWidget {
  final Audiogram audiogram;
  const SpatialAttentionScreen({super.key, required this.audiogram});

  @override
  State<SpatialAttentionScreen> createState() => _SpatialAttentionScreenState();
}

class _SpatialAttentionScreenState extends State<SpatialAttentionScreen> {
  late Audiogram _audiogram;
  late ItemSelector _selector;
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  final GamificationController _gamification = GamificationController();

  int _currentTrial = 0;
  // 20 tentativas por sessão (provisório: redesenho do módulo na Etapa 9 do plano)
  static const int _maxTrials = 20;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  SpatialDirection? _targetDirection;
  bool _canRespond = false;
  bool _isPlaying = false;
  TrialFeedback? _feedback;

  @override
  void initState() {
    super.initState();
    _audiogram = widget.audiogram;
    _selector = ItemSelector(audiogram: _audiogram, warmUpTrials: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// Audiograma do teste antigo? Oferece refazer antes de treinar (o EQ usa o audiograma).
  Future<void> _bootstrap() async {
    _audiogram = await HearingTestFlow.ensureCurrent(context, _audiogram);
    if (!mounted) return;
    await _engine.initializeEngine(_audiogram);
    _startTrial();
  }

  void _startTrial() {
    if (_currentTrial >= _maxTrials) {
      _finishSession();
      return;
    }

    final dirIndex = Random().nextInt(3);
    _targetDirection = SpatialDirection.values[dirIndex];
    setState(() => _canRespond = false);
    _playSpatialSound();
  }

  Future<void> _playSpatialSound() async {
    // Palavra do banco novo (provisório: o redesenho do módulo vem na Etapa 9 do plano).
    final trial = _selector.next();
    final text = trial.played;
    final freqBand = trial.pair.contrast.cueBandHz.toDouble();

    double pan = 0.0;
    if (_targetDirection == SpatialDirection.left) pan = -1.0;
    if (_targetDirection == SpatialDirection.right) pan = 1.0;

    if (_isPlaying) return;
    setState(() {
      _isPlaying = true;
      _canRespond = false;
    });
    try {
      final duration =
          await _engine.playSpatialStimulus(text: text, voice: trial.voice, panning: pan, freqBand: freqBand);
      await Future.delayed(duration); // resposta só depois que a palavra termina
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

  void _handleResponse(SpatialDirection selected) {
    if (!_canRespond) return;

    final isCorrect = selected == _targetDirection;
    if (isCorrect) {
      _correctAnswers++;
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    // Retorno por tentativa (achado D3): de onde o som veio de verdade.
    setState(() {
      _canRespond = false;
      _feedback = TrialFeedback(
        correct: isCorrect,
        correctAnswer: _directionLabel(_targetDirection!),
        selected: _directionLabel(selected),
      );
    });
    if (isCorrect) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted && _feedback != null) _advance();
      });
    }
  }

  static String _directionLabel(SpatialDirection d) => switch (d) {
        SpatialDirection.left => 'esquerda',
        SpatialDirection.center => 'centro',
        SpatialDirection.right => 'direita',
      };

  void _advance() {
    setState(() {
      _feedback = null;
      _currentTrial++;
    });
    _startTrial();
  }

  void _finishSession() async {
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
    final session = RehabSession(
      patientId: _audiogram.patientId,
      date: DateTime.now(),
      level: RehabLevel.spatialAttention,
      totalTrials: _maxTrials,
      correctAnswers: _correctAnswers,
      averageResponseTimeMs: duration / _maxTrials,
      metadata: {'accuracy_pct': (_correctAnswers / _maxTrials * 100).toStringAsFixed(1)},
    );

    _gamification.addAcuityXP(session.accuracy / 100.0, ['spatial']);
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
    SessionSummaryScreen.replaceCurrent(
      context,
      SessionSummary(
            training: 'De onde vem o som',
            correct: _correctAnswers,
            total: _maxTrials,
            duration: Duration(milliseconds: duration),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("De onde vem o som", style: TextStyle(fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _currentTrial / _maxTrials,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
        children: [
          const Text(
            "De onde veio o som?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            "Som ${(_currentTrial + 1).clamp(1, _maxTrials)} de $_maxTrials",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 48),
          const Icon(Icons.headset, size: 100, color: Colors.blueAccent),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SpatialButton(
                label: "ESQUERDA",
                icon: Icons.chevron_left,
                onPressed: _canRespond ? () => _handleResponse(SpatialDirection.left) : null,
              ),
              const SizedBox(width: 20),
              _SpatialButton(
                label: "CENTRO",
                icon: Icons.center_focus_strong,
                onPressed: _canRespond ? () => _handleResponse(SpatialDirection.center) : null,
              ),
              const SizedBox(width: 20),
              _SpatialButton(
                label: "DIREITA",
                icon: Icons.chevron_right,
                onPressed: _canRespond ? () => _handleResponse(SpatialDirection.right) : null,
              ),
            ],
          ),
          const SizedBox(height: 40),
          if (_feedback != null) ...[
            const SizedBox(height: 24),
            FeedbackBanner(feedback: _feedback!, onContinue: _feedback!.correct ? null : _advance),
          ],
          TextButton.icon(
            onPressed: _isPlaying ? null : _playSpatialSound,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Repetir", style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
          ),
        ],
        ),
      ),
    );
  }
}

class _SpatialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SpatialButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: onPressed != null ? const Color(0xFF1E1E24) : Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: onPressed != null ? Colors.white10 : Colors.transparent),
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 32, color: onPressed != null ? Colors.blueAccent : Colors.white24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
