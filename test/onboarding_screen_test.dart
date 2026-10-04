import 'package:ear_training/ui/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// O motor nativo não existe no teste: o check de som cai no catch e segue para a pergunta,
// que é o comportamento a verificar aqui.
void main() {
  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> goToSoundCheck(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('textos em linguagem comum e adiamento explícito',
      (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Antes de começar'), findsOneWidget);
    expect(find.text('Fazer o teste depois'), findsOneWidget);
    expect(find.text('PULAR TESTE'), findsNothing);
    expect(find.bySemanticsLabel('Próximo'), findsOneWidget);
  });

  testWidgets('check de som pergunta se ouviu e orienta quando não ouviu',
      (tester) async {
    await pumpOnboarding(tester);
    await goToSoundCheck(tester);

    expect(find.text('Prepare o fone'), findsOneWidget);
    await tester.tap(find.text('Tocar som de teste'));
    await tester.pumpAndSettle();

    expect(find.text('Você ouviu o som?'), findsOneWidget);
    await tester.tap(find.text('Não ouvi'));
    await tester.pump();
    expect(find.textContaining('aumente o volume'), findsOneWidget);
    expect(find.text('Tocar de novo'), findsOneWidget);
  });

  testWidgets('última página explica o teste e o botão diz o que faz',
      (tester) async {
    await pumpOnboarding(tester);
    await goToSoundCheck(tester);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('Teste de audição'), findsOneWidget);
    expect(find.textContaining('mesmo quando o som for bem fraquinho'),
        findsOneWidget);
    expect(find.text('Começar o teste'), findsOneWidget);
  });

  testWidgets('cabe em 360x640 com fonte em 200%, sem estourar o layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(360, 640), textScaler: TextScaler.linear(2)),
        child: OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Começar o teste'), findsOneWidget);
  });
}
