import 'package:ear_training/models/rehab_session.dart';
import 'package:ear_training/training/progress_rules.dart';
import 'package:flutter_test/flutter_test.dart';

RehabSession _s(DateTime date, int minutes, {RehabLevel level = RehabLevel.phonemicDiscrimination, Map<String, dynamic>? meta}) =>
    RehabSession(
      patientId: 'p',
      date: date,
      level: level,
      totalTrials: 20,
      correctAnswers: 15,
      averageResponseTimeMs: 0,
      metadata: {'duration_ms': minutes * 60000, ...?meta},
    );

void main() {
  final now = DateTime(2026, 10, 8, 18); // quinta-feira

  test('minutos do dia somam todas as sessões (achado E3: "SESSÕES HOJE: 3 / 2")', () {
    final history = [_s(DateTime(2026, 10, 8, 9), 6), _s(DateTime(2026, 10, 8, 12), 5), _s(DateTime(2026, 10, 7, 20), 30)];
    expect(ProgressRules.minutesOn(history, now), 11);
    expect(ProgressRules.minutesLeftToday(11), 4);
  });

  test('sessões antigas sem duration_ms usam tempo médio × tentativas', () {
    final old = RehabSession(
        patientId: 'p', date: now, level: RehabLevel.speechInNoise, totalTrials: 20, correctAnswers: 10, averageResponseTimeMs: 6000);
    expect(ProgressRules.durationOf(old), const Duration(minutes: 2));
  });

  test('dias seguidos contam dias com a meta e não sobem ao reabrir (achado E3)', () {
    final history = [
      _s(DateTime(2026, 10, 5, 10), 20), // segunda
      _s(DateTime(2026, 10, 6, 10), 15), // terça
      _s(DateTime(2026, 10, 7, 10), 16), // quarta
      // quinta (hoje): ainda 5 min, a sequência termina ontem
      _s(DateTime(2026, 10, 8, 8), 5),
    ];
    expect(ProgressRules.streakDays(history, now), 3);
    expect(ProgressRules.streakDays(history, now), 3); // recalcular não muda
    expect(ProgressRules.goalDaysThisWeek(history, now), 3);

    // Três sessões curtas no primeiro dia: meta cumprida = 1 dia (antes: "STREAK 0 dias").
    final firstDay = [_s(DateTime(2026, 10, 8, 8), 5), _s(DateTime(2026, 10, 8, 9), 5), _s(DateTime(2026, 10, 8, 10), 5)];
    expect(ProgressRules.streakDays(firstDay, now), 1);
    expect(ProgressRules.days(1), '1 dia');
    expect(ProgressRules.days(3), '3 dias');
  });

  test('níveis em linguagem comum e estágios', () {
    expect(ProgressRules.phonemicLevel(24), 1);
    expect(ProgressRules.phonemicLevel(0), 7);
    expect(ProgressRules.noiseLevel(15), 1);
    expect(ProgressRules.noiseLevel(-10), 10);
    expect(ProgressRules.stageName(2, 7), 'Começando');
    expect(ProgressRules.stageName(4, 7), 'Avançando');
    expect(ProgressRules.stageName(9, 10), 'Dominando');
    expect(ProgressRules.sessionLevel(_s(now, 10, meta: {'boost_threshold_db': 8.0})), ProgressRules.phonemicLevel(8));
    expect(
        ProgressRules.sessionLevel(_s(now, 10, level: RehabLevel.speechInNoise, meta: {'final_snr': -2.0})),
        ProgressRules.noiseLevel(-2));
    expect(ProgressRules.sessionLevel(_s(now, 4, level: RehabLevel.digitsInNoise)), isNull);
  });

  test('recorde: menor limiar é melhor; primeira medida conta', () {
    expect(ProgressRules.isNewBest(null, 5), isTrue);
    expect(ProgressRules.isNewBest(5, 3), isTrue);
    expect(ProgressRules.isNewBest(5, 6), isFalse);
    expect(ProgressRules.isNewBest(5, null), isFalse);
  });

  test('recomendação por domínio: Palavras parecidas até o nível 5; depois os treinos com ruído', () {
    expect(ProgressRules.recommend(levels: {TrainingId.phonemic: 3}, hasPro: true), TrainingId.phonemic);
    expect(ProgressRules.recommend(levels: {TrainingId.phonemic: 6}, hasPro: false), TrainingId.phonemic);
    expect(ProgressRules.recommend(levels: {TrainingId.phonemic: 6, TrainingId.cocktail: 2}, hasPro: true),
        TrainingId.cocktail);
    expect(ProgressRules.recommend(levels: {TrainingId.phonemic: 6, TrainingId.cocktail: 7}, hasPro: true),
        TrainingId.spatial);
  });
}
