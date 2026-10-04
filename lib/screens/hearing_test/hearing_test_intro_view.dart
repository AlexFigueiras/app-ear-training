import 'package:flutter/material.dart';

import '../../services/audio_output_service.dart';
import '../../ui/theme/bosyn_text.dart';

/// Instruções antes do teste (achado C3): como responder, fone, silêncio e volume fixo.
/// A checagem de ambiente silencioso é por confirmação da pessoa: medir o ruído exigiria
/// permissão de microfone, que o app não pede.
class HearingTestIntroView extends StatelessWidget {
  final OutputRoute route;
  final bool quietConfirmed;
  final ValueChanged<bool> onQuietChanged;
  final VoidCallback onRecheckRoute;
  final VoidCallback onStart;

  const HearingTestIntroView({
    super.key,
    required this.route,
    required this.quietConfirmed,
    required this.onQuietChanged,
    required this.onRecheckRoute,
    required this.onStart,
  });

  bool get _canStart => quietConfirmed && route != OutputRoute.speaker;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Teste de audição', style: BosynText.title),
          const SizedBox(height: 16),
          const _Step('Leva uns 10 minutos. É um ouvido de cada vez: primeiro o esquerdo, depois o direito.'),
          const _Step('Você vai ouvir 3 bipes curtos. Toque em "Ouvi" sempre que ouvir, mesmo que seja '
              'bem fraquinho.'),
          const _Step('Às vezes não toca nada, de propósito. Se não ouviu nada, toque em "Não ouvi".'),
          const _Step('Ajuste agora o volume do celular num nível confortável e não mexa mais até o fim.'),
          const SizedBox(height: 8),
          _routeStatus(),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: quietConfirmed,
            onChanged: (v) => onQuietChanged(v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Estou num lugar silencioso (TV, rádio e ventilador desligados).',
              style: BosynText.body,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _canStart ? onStart : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text('Começar', style: BosynText.button),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeStatus() {
    final (String text, Color color) = switch (route) {
      OutputRoute.wired => ('Fone com fio conectado.', const Color(0xFF4ADE80)),
      OutputRoute.bluetooth => (
          'Fone Bluetooth conectado. Funciona, mas o fone com fio dá um resultado mais preciso.',
          const Color(0xFFFBBF24)
        ),
      OutputRoute.speaker => ('Conecte um fone de ouvido para fazer o teste.', const Color(0xFFF87171)),
      OutputRoute.unknown => ('Use fone de ouvido, de preferência com fio.', BosynText.secondary),
    };
    return Row(
      children: [
        Expanded(child: Text(text, style: BosynText.body.copyWith(color: color))),
        if (route == OutputRoute.speaker || route == OutputRoute.bluetooth)
          TextButton(onPressed: onRecheckRoute, child: const Text('Verificar', style: TextStyle(fontSize: 16))),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String text;

  const _Step(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  ', style: BosynText.body),
          Expanded(child: Text(text, style: BosynText.body)),
        ]),
      );
}
