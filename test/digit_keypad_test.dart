import 'package:ear_training/screens/widgets/digit_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('digita até 3 números, apaga e só confirma com os 3', (tester) async {
    var entered = <int>[];
    var confirmed = 0;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DigitKeypad(
            entered: entered,
            enabled: true,
            onDigit: (d) => setState(() => entered = [...entered, d]),
            onBackspace: () => setState(() => entered = entered.sublist(0, entered.length - 1)),
            onConfirm: () => confirmed++,
          ),
        ),
      ),
    ));

    await tester.tap(find.bySemanticsLabel('Confirmar'));
    expect(confirmed, 0); // nada digitado

    for (final d in ['4', '7', '2', '9']) {
      await tester.tap(find.bySemanticsLabel(d));
      await tester.pump();
    }
    expect(entered, [4, 7, 2]); // a 4ª tecla não entra

    await tester.tap(find.bySemanticsLabel('Apagar'));
    await tester.pump();
    expect(entered, [4, 7]);

    await tester.tap(find.bySemanticsLabel('1'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Confirmar'));
    expect(confirmed, 1);
  });
}
