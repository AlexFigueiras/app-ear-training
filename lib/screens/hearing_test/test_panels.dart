import 'package:flutter/material.dart';

import '../../ui/theme/bosyn_text.dart';

// Painéis do teste de audição (instrução por ouvido e resposta "Ouvi"/"Não ouvi").

class EarIntroPanel extends StatelessWidget {
  final String ear;
  final VoidCallback onContinue;

  const EarIntroPanel({
    super.key,required this.ear, required this.onContinue});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Agora: ouvido $ear', style: BosynText.title),
          const SizedBox(height: 12),
          Text('Os bipes vão tocar só no ouvido $ear. Confira se o fone está no lado certo '
              '(a letra ${ear == 'esquerdo' ? 'L ou E' : 'R ou D'} no fone).', style: BosynText.body),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text('Começar', style: BosynText.button),
            ),
          ),
        ]),
      );
}

class AnswerPanel extends StatelessWidget {
  final String heading;
  final String instruction;
  final double? progress;
  final bool playing;
  final bool canAnswer;
  final String? notice;
  final ValueChanged<bool> onAnswer;
  final VoidCallback? onReplay;

  const AnswerPanel({
    super.key,
    required this.heading,
    required this.instruction,
    required this.playing,
    required this.canAnswer,
    required this.onAnswer,
    this.progress,
    this.notice,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (progress != null) ...[
            LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white12),
            const SizedBox(height: 16),
          ],
          Text(heading, style: BosynText.title),
          const SizedBox(height: 32),
          Icon(Icons.hearing, size: 72, color: playing ? const Color(0xFF60A5FA) : Colors.white24),
          const SizedBox(height: 24),
          Text(instruction, style: BosynText.heading, textAlign: TextAlign.center),
          if (notice != null) ...[
            const SizedBox(height: 16),
            Text(notice!, style: BosynText.body.copyWith(color: const Color(0xFFFBBF24)), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: AnswerButton(label: 'Não ouvi', enabled: canAnswer, onTap: () => onAnswer(false))),
            const SizedBox(width: 16),
            Expanded(
                child: AnswerButton(label: 'Ouvi', enabled: canAnswer, primary: true, onTap: () => onAnswer(true))),
          ]),
          if (onReplay != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onReplay, child: const Text('Tocar de novo', style: TextStyle(fontSize: 16))),
          ],
        ]),
      );
}

class AnswerButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;

  const AnswerButton({
    super.key,required this.label, required this.enabled, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 72,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary ? const Color(0xFF2563EB) : const Color(0xFF2A2A33),
            foregroundColor: Colors.white,
          ),
          child: FittedBox(child: Text(label, style: BosynText.button)),
        ),
      );
}
