import 'package:ear_training/ui/screens/auth_screen.dart';
import 'package:ear_training/ui/screens/password_reset_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Só caminhos que não chegam ao Supabase: a validação local acontece antes da chamada.
void main() {
  Future<void> pumpAuth(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
  }

  testWidgets('campos têm nome acessível e textos em linguagem comum',
      (tester) async {
    await pumpAuth(tester);

    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Senha'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.text('TERMINAL ACCESS'), findsNothing);
  });

  testWidgets('erro de validação aparece junto do campo, sem ir ao servidor',
      (tester) async {
    await pumpAuth(tester);

    await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'maria@');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();

    expect(find.textContaining('nome@exemplo.com'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });

  testWidgets('botão de mostrar senha alterna e tem nome', (tester) async {
    await pumpAuth(tester);

    expect(find.byTooltip('Mostrar senha'), findsOneWidget);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);
  });

  testWidgets('cadastro só libera o botão com o consentimento marcado',
      (tester) async {
    await pumpAuth(tester);

    await tester.tap(find.text('Primeira vez aqui? Criar conta'));
    await tester.pump();

    final button = find.widgetWithText(ElevatedButton, 'Criar conta');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(find.text('Pelo menos 8 caracteres.'), findsOneWidget);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
  });

  testWidgets('"Esqueci minha senha" abre a recuperação com o e-mail digitado',
      (tester) async {
    await pumpAuth(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'maria@exemplo.com');
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.byType(PasswordResetScreen), findsOneWidget);
    expect(find.text('maria@exemplo.com'), findsOneWidget);
    expect(
        find.widgetWithText(ElevatedButton, 'Enviar código'), findsOneWidget);
  });
}
