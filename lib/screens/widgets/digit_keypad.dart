import 'package:flutter/material.dart';

import '../../ui/theme/bosyn_text.dart';

/// Teclado do teste de dígitos: 3 casas para os números ouvidos, teclas 0–9, apagar e confirmar.
/// Teclas grandes (64 dp) com nome para o leitor de tela.
class DigitKeypad extends StatelessWidget {
  final List<int> entered;
  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onConfirm;

  const DigitKeypad({
    super.key,
    required this.entered,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final full = entered.length == 3;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 64,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: i == entered.length && enabled ? Colors.white : BosynText.outline, width: 2),
            ),
            child: FittedBox(
              child: Text(i < entered.length ? '' : '',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
      ]),
      const SizedBox(height: 24),
      for (final row in const [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
        [-1, 0, -2],
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final key in row) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _key(key, full)),
          ]),
        ),
    ]);
  }

  Widget _key(int key, bool full) {
    if (key == -1) {
      return _button(
        label: 'Apagar',
        child: const Icon(Icons.backspace_outlined, size: 28),
        onPressed: enabled && entered.isNotEmpty ? onBackspace : null,
      );
    }
    if (key == -2) {
      return _button(
        label: 'Confirmar',
        child: const Icon(Icons.check, size: 32),
        onPressed: enabled && full ? onConfirm : null,
        primary: true,
      );
    }
    return _button(
      label: '$key',
      child: FittedBox(child: Text('$key', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
      onPressed: enabled && !full ? () => onDigit(key) : null,
    );
  }

  Widget _button({required String label, required Widget child, VoidCallback? onPressed, bool primary = false}) =>
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          width: 80,
          height: 64,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary ? const Color(0xFF2563EB) : const Color(0xFF2A2A33),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      );
}
