import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/audiogram.dart';
import '../../services/audio_service_manager.dart';

/// Painel de QA de áudio (só em debug/profile, dentro do painel técnico).
///
/// Serve ao checklist de escuta de cada etapa: tons por orelha (sem EQ, com rampa), a mesma
/// palavra com e sem o EQ do paciente, e o contador do limitador de segurança, que deveria ficar
/// em 0 numa sessão normal.
class QaAudioPanel extends StatefulWidget {
  const QaAudioPanel({super.key});

  @override
  State<QaAudioPanel> createState() => _QaAudioPanelState();
}

class _QaAudioPanelState extends State<QaAudioPanel> {
  String _status = '';

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _status = 'Tocando: $label');
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = 'Erro: $e');
    }
  }

  Future<void> _tone(EarSide ear) async {
    final engine = AudioServiceManager().engine;
    if (!engine.isInitialized) {
      setState(() => _status = 'Abra um treino uma vez antes (o motor ainda não iniciou).');
      return;
    }
    await engine.playPureTone(frequencyHz: 1000, durationMs: 1000, ear: ear, dbLevel: 50);
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    final engine = AudioServiceManager().engine;
    final profile = engine.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QA DE ÁUDIO', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('EQ esq: ${profile.left.map((g) => g.toStringAsFixed(0)).join(' ')} dB',
            style: const TextStyle(color: Colors.white54, fontSize: 14, fontFamily: 'monospace')),
        Text('EQ dir: ${profile.right.map((g) => g.toStringAsFixed(0)).join(' ')} dB',
            style: const TextStyle(color: Colors.white54, fontSize: 14, fontFamily: 'monospace')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _button('Tom esquerda', () => _run('tom esquerda', () => _tone(EarSide.left))),
            _button('Tom direita', () => _run('tom direita', () => _tone(EarSide.right))),
            _button('"Sala" sem EQ', () => _run('"sala" sem EQ', () => engine.playQaWord('Sala', withEq: false))),
            _button('"Sala" com EQ', () => _run('"sala" com EQ', () => engine.playQaWord('Sala', withEq: true))),
            _button('Zerar limitador', () async {
              engine.native.resetLimiterHits();
              setState(() => _status = 'Contador do limitador zerado.');
            }),
          ],
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ],
    );
  }

  Widget _button(String label, VoidCallback onPressed) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      );
}
