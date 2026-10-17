import 'package:ear_training/screens/session_summary_screen.dart';
import 'package:ear_training/screens/widgets/noise_level_header.dart';
import 'package:ear_training/screens/widgets/trial_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('erro mostra a palavra certa, a marcada, "Ouvir as duas" e "Continuar"', (tester) async {
    var listened = 0, continued = 0;
    await tester.pumpWidget(_wrap(FeedbackBanner(
      feedback: const TrialFeedback(correct: false, correctAnswer: 'sala', selected: 'fala'),
      onListenBoth: () => listened++,
      onContinue: () => continued++,
    )));

    expect(find.text('Era "sala"'), findsOneWidget);
    expect(find.text('Você marcou "fala".'), findsOneWidget);
    await tester.tap(find.text('Ouvir as duas'));
    await tester.tap(find.text('Continuar'));
    expect(listened, 1);
    expect(continued, 1);
  });

  testWidgets('acerto mostra "Certo!" sem botões (avança sozinho)', (tester) async {
    await tester.pumpWidget(_wrap(const FeedbackBanner(
      feedback: TrialFeedback(correct: true, correctAnswer: 'sala', selected: 'sala'),
    )));
    expect(find.text('Certo!'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Ouvir as duas'), findsNothing);
  });

  test('destaque: verde na certa, vermelho na marcada, nada sem retorno', () {
    const f = TrialFeedback(correct: false, correctAnswer: 'sala', selected: 'fala');
    expect(feedbackHighlight(f, 'sala'), FeedbackColors.correct);
    expect(feedbackHighlight(f, 'fala'), FeedbackColors.wrong);
    expect(feedbackHighlight(null, 'sala'), isNull);
  });

  testWidgets('resumo de fim de sessão: acertos, tempo, nível e volta ao início', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SessionSummaryScreen(
                summary: SessionSummary(
                  training: 'Palavras parecidas',
                  correct: 18,
                  total: 25,
                  duration: Duration(minutes: 2, seconds: 30),
                  levelLine: 'Nível de dificuldade alcançado: 4 de 7',
                ),
              ),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('18 de 25'), findsOneWidget);
    expect(find.text('acertos (72%)'), findsOneWidget);
    expect(find.text('Tempo de treino: 3 min'), findsOneWidget);
    expect(find.text('Nível de dificuldade alcançado: 4 de 7'), findsOneWidget);

    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });

  test('nível de ruído em linguagem comum: +15 dB = 1, -10 dB = 10, com limites', () {
    expect(NoiseLevelHeader.levelOf(15), 1);
    expect(NoiseLevelHeader.levelOf(-10), 10);
    expect(NoiseLevelHeader.levelOf(20), 1);
    expect(NoiseLevelHeader.levelOf(-20), 10);
  });
}
