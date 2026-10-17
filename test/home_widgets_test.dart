import 'package:ear_training/ui/screens/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {double textScale = 1}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
              size: const Size(360, 640),
              textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: ListView(children: [child])),
        ),
      );

  testWidgets('card de treino reflete o plano: bloqueado diz como liberar',
      (tester) async {
    final level = TrainingLevel.all[1];
    await tester
        .pumpWidget(host(LevelCard(level: level, locked: true, onTap: () {})));

    expect(find.text('Voz de um lado, barulho do outro'), findsOneWidget);
    expect(find.text('Plano PRO ou um vídeo por sessão'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('REQUER PRO'), findsNothing);
  });

  testWidgets('card liberado não mostra cadeado e anuncia o treino inteiro',
      (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(host(LevelCard(
        level: TrainingLevel.all[2],
        locked: false,
        onTap: () => tapped = true)));

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Conversa no barulho\. Entenda')),
        findsOneWidget);
    await tester.tap(find.text('Conversa no barulho'));
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('cartão de próximo passo cabe com fonte em 200% em 360x640',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var pressed = false;
    await tester.pumpWidget(host(
      NextStepCard(
        title: 'Comece pelo teste de audição',
        body: 'Leva alguns minutos e ajusta o treino ao seu jeito de ouvir.',
        actionLabel: 'Fazer o teste agora',
        onPressed: () => pressed = true,
      ),
      textScale: 2,
    ));

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Fazer o teste agora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazer o teste agora'));
    expect(pressed, isTrue);
  });

  testWidgets('estado vazio do gráfico explica em vez de mostrar 0%',
      (tester) async {
    await tester.pumpWidget(host(const EmptyProgressNote()));
    expect(find.textContaining('depois do primeiro treino'), findsOneWidget);
  });
}
