import 'package:ear_training/models/audiogram.dart';
import 'package:ear_training/models/rehab_session.dart';
import 'package:ear_training/screens/hearing_test/hearing_test_intro_view.dart';
import 'package:ear_training/screens/hearing_test/hearing_test_result_view.dart';
import 'package:ear_training/screens/hearing_test/test_panels.dart';
import 'package:ear_training/screens/session_summary_screen.dart';
import 'package:ear_training/screens/widgets/choice_grid.dart';
import 'package:ear_training/screens/widgets/digit_keypad.dart';
import 'package:ear_training/screens/widgets/noise_level_header.dart';
import 'package:ear_training/screens/widgets/trial_feedback.dart';
import 'package:ear_training/services/audio_output_service.dart';
import 'package:ear_training/training/progress_rules.dart';
import 'package:ear_training/ui/screens/home/daily_goal_card.dart';
import 'package:ear_training/ui/screens/home/training_progress_section.dart';
import 'package:ear_training/ui/screens/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Achado G3 da auditoria de UX: com a fonte do celular em 200% a Home e as opções do treino
/// cortavam. Cada peça das telas é montada em 360×640 com fonte em 200%; um estouro de layout
/// (RenderFlex overflow) faz o teste falhar.
Future<void> _pumpLarge(WidgetTester tester, Widget child, {bool scroll = true}) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(2.0)),
      child: Scaffold(body: scroll ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: child) : child),
    ),
  ));
  await tester.pump();
}

Audiogram _audiogram() {
  List<AudiometryPoint> ear() => [
        for (final e in {250: 10.0, 500: 10.0, 1000: 15.0, 2000: 25.0, 3000: 35.0, 4000: 45.0, 6000: 55.0, 8000: 80.0}.entries)
          AudiometryPoint(frequency: e.key, threshold: e.value, protocol: 2, noResponse: e.key == 8000),
      ];
  return Audiogram(id: '', patientId: '', date: DateTime(2026, 10, 5), leftEar: ear(), rightEar: ear());
}

void main() {
  testWidgets('retorno de erro com "Ouvir as duas" e "Continuar"', (tester) async {
    await _pumpLarge(
      tester,
      FeedbackBanner(
        feedback: const TrialFeedback(correct: false, correctAnswer: 'assado', selected: 'achado'),
        nowPlaying: 'Certa: "assado"',
        onListenBoth: () {},
        onContinue: () {},
      ),
    );
  });

  testWidgets('4 opções do Coquetel e nível de ruído', (tester) async {
    await _pumpLarge(
      tester,
      Column(children: [
        const NoiseLevelHeader(snrDb: -4),
        ChoiceGrid(options: const ['mancha', 'mansa', 'manchas', 'mansas'], enabled: true, feedback: null, onChoose: (_) {}),
      ]),
    );
  });

  testWidgets('teclado do teste de dígitos', (tester) async {
    await _pumpLarge(
      tester,
      DigitKeypad(entered: const [4, 7], enabled: true, onDigit: (_) {}, onBackspace: () {}, onConfirm: () {}),
    );
  });

  testWidgets('resumo de fim de sessão', (tester) async {
    await _pumpLarge(
      tester,
      const SessionSummaryScreen(
        summary: SessionSummary(
          training: 'Voz de um lado, barulho do outro',
          correct: 41,
          total: 52,
          duration: Duration(minutes: 10),
          levelLine: 'Nível de ruído alcançado: 6 de 10',
          reward: SessionReward(points: 180, newBest: true, goalJustReached: true),
          minutesToday: 16,
        ),
      ),
      scroll: false,
    );
  });

  testWidgets('Home: meta do dia, evolução e cartão de treino', (tester) async {
    final history = [
      for (var i = 0; i < 6; i++)
        RehabSession(
          patientId: 'p',
          date: DateTime(2026, 10, 1 + i),
          level: RehabLevel.phonemicDiscrimination,
          totalTrials: 40,
          correctAnswers: 32,
          averageResponseTimeMs: 0,
          metadata: {'boost_threshold_db': 16.0 - i * 2, 'duration_ms': 600000},
        ),
    ];
    await _pumpLarge(
      tester,
      Column(children: [
        const DailyGoalCard(minutesToday: 32, streakDays: 3, goalDaysThisWeek: 3, points: 1250),
        TrainingProgressSection(history: history),
        LevelCard(
          level: TrainingLevel.all.first,
          locked: false,
          recommended: true,
          progressLine: 'Nível 4 de 7 · Avançando',
          onTap: () {},
        ),
        NextStepCard(title: 'Hora de medir sua audição na fala', body: 'A cada 14 dias.', actionLabel: 'Medir agora', onPressed: () {}),
      ]),
    );
    expect(find.text('Recomendado para você'), findsOneWidget);
    expect(find.text('Dias seguidos com a meta: ${ProgressRules.days(3)}'), findsOneWidget);
  });

  testWidgets('teste de audição: instruções, resposta e resultado', (tester) async {
    await _pumpLarge(
      tester,
      HearingTestIntroView(
        route: OutputRoute.bluetooth,
        quietConfirmed: true,
        onQuietChanged: (_) {},
        onRecheckRoute: () {},
        onStart: () {},
      ),
      scroll: false,
    );
    await _pumpLarge(
      tester,
      AnswerPanel(
        heading: 'Ouvido esquerdo',
        instruction: 'Você ouviu os bipes?',
        progress: 0.4,
        playing: false,
        canAnswer: true,
        notice: 'Toque em "Ouvi" só quando tiver certeza de que ouviu o bipe.',
        onAnswer: (_) {},
      ),
      scroll: false,
    );
    await _pumpLarge(
      tester,
      HearingTestResultView(audiogram: _audiogram(), onSave: () {}, onRetest: () {}),
      scroll: false,
    );
  });
}
