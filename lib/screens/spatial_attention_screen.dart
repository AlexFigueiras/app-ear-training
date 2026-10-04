import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../audio_engine/audio_engine.dart';
import '../core/gamification_controller.dart';
import '../models/audiogram.dart';
import '../models/rehab_session.dart';
import '../services/supabase_service.dart';

enum SpatialDirection { left, center, right }

class SpatialAttentionScreen extends StatefulWidget {
  final Audiogram audiogram;
  const SpatialAttentionScreen({super.key, required this.audiogram});

  @override
  State<SpatialAttentionScreen> createState() => _SpatialAttentionScreenState();
}

class _SpatialAttentionScreenState extends State<SpatialAttentionScreen> {
  final AudioRehabEngine _engine = AudioRehabEngine();
  final SupabaseService _supabase = SupabaseService();
  final GamificationController _gamification = GamificationController();

  int _currentTrial = 0;
  // Dose mínima efetiva
  static const int _maxTrials = 20;
  int _correctAnswers = 0;
  final DateTime _sessionStart = DateTime.now();

  SpatialDirection? _targetDirection;
  bool _canRespond = false;

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

    final dirIndex = Random().nextInt(3);
    _targetDirection = SpatialDirection.values[dirIndex];
    setState(() => _canRespond = false);
    _playSpatialSound();
  }

  Future<void> _playSpatialSound() async {
    // Usa fonema priorizado pela zona de perda do paciente
    final phoneme = _gamification.getSmartPhoneme(_audiogramData);
    final text = phoneme?['target'] as String? ?? 'Saco';
    final freqBand = (phoneme?['freq_band'] as num?)?.toDouble() ?? 5000.0;

    double pan = 0.0;
    if (_targetDirection == SpatialDirection.left) pan = -1.0;
    if (_targetDirection == SpatialDirection.right) pan = 1.0;

    await _engine.playSpatialStimulus(text: text, panning: pan, freqBand: freqBand);
    setState(() => _canRespond = true);
  }

  void _handleResponse(SpatialDirection selected) {
    if (!_canRespond) return;

    final isCorrect = selected == _targetDirection;
    if (isCorrect) {
      _correctAnswers++;
      HapticFeedback.lightImpact();
    } else {
      _gamification.consumeEnergy();
      HapticFeedback.heavyImpact();
    }

    setState(() => _currentTrial++);
    _startTrial();
  }

  void _finishSession() async {
    final duration = DateTime.now().difference(_sessionStart).inMilliseconds;
    final session = RehabSession(
      patientId: widget.audiogram.patientId,
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: const Text("Treino Espacial Concluído", style: TextStyle(color: Colors.white)),
            content: Text(
              "Acertos: $_correctAnswers / $_maxTrials\nPrecisão: ${session.accuracy.toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Color(0xFF00FF41))),
              ),
            ],
          ),
        ).then((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
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
        title: const Text("NÍVEL 3: ATENÇÃO ESPACIAL"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _currentTrial / _maxTrials,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "De onde veio o som?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            "Trial ${_currentTrial + 1} / $_maxTrials",
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
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
          TextButton.icon(
            onPressed: _canRespond ? null : _playSpatialSound,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Repetir", style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
          ),
        ],
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
