import 'package:ear_training/monetization/plan_offer.dart';
import 'package:ear_training/ui/screens/pro_offer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _plans = [
  PlanOffer(productId: 'bosyn_pro_mensal', price: r'R$ 19,90'),
  PlanOffer(productId: 'bosyn_pro_anual', price: r'R$ 179,90'),
];

/// Abre a folha a partir de um botão e devolve a escolha feita (ou null).
Future<ProChoice?> _openAndChoose(
  WidgetTester tester, {
  required Future<void> Function() choose,
  List<PlanOffer> plans = _plans,
  bool storeAvailable = true,
  int videosLeft = 2,
  bool videosAvailable = true,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  ProChoice? result;
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
          size: const Size(360, 640), textScaler: TextScaler.linear(textScale)),
      child: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showProOfferSheet(
              context,
              trainingTitle: 'Conversa no barulho',
              plans: plans,
              storeAvailable: storeAvailable,
              videosLeft: videosLeft,
              videosAvailable: videosAvailable,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  await choose();
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets(
      'mostra preço, período, renovação e cancelamento; assinar devolve o plano',
      (tester) async {
    final choice = await _openAndChoose(tester, choose: () async {
      expect(
          find.textContaining('"Conversa no barulho" faz parte do plano PRO'),
          findsOneWidget);
      expect(find.text(r'Assinar Mensal: R$ 19,90 por mês'), findsOneWidget);
      expect(find.text(r'Assinar Anual: R$ 179,90 por ano'), findsOneWidget);
      expect(
          find.textContaining(
              'renova sozinha pelo mesmo preço até você cancelar'),
          findsOneWidget);
      expect(find.textContaining('Pagamentos e assinaturas'), findsOneWidget);
      expect(find.textContaining('Restam 2 vídeos hoje.'), findsOneWidget);
      await tester.tap(find.text(r'Assinar Anual: R$ 179,90 por ano'));
    });
    expect(choice?.kind, ProChoiceKind.subscribe);
    expect(choice?.productId, 'bosyn_pro_anual');
  });

  testWidgets('ver vídeo e restaurar devolvem a escolha certa', (tester) async {
    final video = await _openAndChoose(tester, videosLeft: 1, choose: () async {
      expect(find.textContaining('Resta 1 vídeo hoje.'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver vídeo e treinar'));
      await tester.tap(find.text('Ver vídeo e treinar'));
    });
    expect(video?.kind, ProChoiceKind.watchVideo);

    final restore = await _openAndChoose(tester, choose: () async {
      await tester.ensureVisible(find.text('Já assino: restaurar compra'));
      await tester.tap(find.text('Já assino: restaurar compra'));
    });
    expect(restore?.kind, ProChoiceKind.restore);
  });

  testWidgets('sem loja: explica e não mostra botão de compra', (tester) async {
    await _openAndChoose(tester, storeAvailable: false, choose: () async {
      expect(find.textContaining('A assinatura não está disponível agora'),
          findsOneWidget);
      expect(find.textContaining('Assinar Mensal'), findsNothing);
    });
  });

  testWidgets(
      'vídeos do dia usados ou indisponíveis: botão desligado e motivo na tela',
      (tester) async {
    await _openAndChoose(tester, videosLeft: 0, choose: () async {
      expect(find.textContaining('Você já usou os vídeos de hoje'),
          findsOneWidget);
      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Ver vídeo e treinar'));
      expect(button.onPressed, isNull);
      await tester.ensureVisible(find.text('Agora não'));
      await tester.tap(find.text('Agora não'));
    });
    await _openAndChoose(tester, videosAvailable: false, choose: () async {
      expect(find.textContaining('Os vídeos não estão disponíveis agora'),
          findsOneWidget);
    });
  });

  testWidgets('cabe em 360x640 com fonte em 200% (rola, sem estouro)',
      (tester) async {
    await _openAndChoose(tester, textScale: 2, choose: () async {
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Agora não'));
      await tester.tap(find.text('Agora não'));
    });
  });
}
