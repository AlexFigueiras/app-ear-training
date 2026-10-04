import 'package:ear_training/core/legal_documents.dart';
import 'package:ear_training/ui/screens/legal_document_screen.dart';
import 'package:ear_training/ui/screens/startup_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('configuração inválida aparece na tela em vez de quebrar o app',
      (tester) async {
    await tester.pumpWidget(
        const StartupErrorApp(problems: ['SUPABASE_URL não definida.']));

    expect(find.text('NÃO FOI POSSÍVEL INICIAR O BOSYN'), findsOneWidget);
    expect(find.text('• SUPABASE_URL não definida.'), findsOneWidget);
  });

  testWidgets('política de privacidade é exibida dentro do app',
      (tester) async {
    await tester.runAsync(
        () => rootBundle.loadString(LegalDocuments.privacyPolicyAsset));

    await tester.pumpWidget(const MaterialApp(
      home: LegalDocumentScreen(
        title: 'POLÍTICA DE PRIVACIDADE',
        assetPath: LegalDocuments.privacyPolicyAsset,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Política de Privacidade do BOSYN'), findsOneWidget);
    expect(
        find.text('1. Quem é o responsável pelos seus dados'), findsOneWidget);
  });
}
