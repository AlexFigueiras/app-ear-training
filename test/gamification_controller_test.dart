import 'package:ear_training/core/gamification_controller.dart';
import 'package:ear_training/training/progress_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final controller = GamificationController();
  setUp(controller.resetForNewUser);

  test('pontos por esforço iguais em todos os treinos, com bônus de recorde e de meta', () {
    controller.setDailyProgress(minutesToday: 8, streakDays: 0, goalDaysThisWeek: 0);

    // 10 min de Palavras parecidas, primeiro limiar (recorde) e meta cruzada (8 -> 18 min).
    final first = controller.completeSession(module: 'phonemic', threshold: 10, duration: const Duration(minutes: 10));
    expect(first.newBest, isTrue);
    expect(first.goalJustReached, isTrue);
    expect(first.points, 100 + ProgressRules.bestBonus + ProgressRules.goalBonus);

    // 10 min de Conversa no barulho: mesmos 100 pontos pelo tempo; recorde (primeiro limiar).
    final noise = controller.completeSession(module: 'cocktail', threshold: 2, duration: const Duration(minutes: 10));
    expect(noise.points, 100 + ProgressRules.bestBonus);
    expect(noise.goalJustReached, isFalse); // a meta já tinha sido cumprida

    // Pior que o recorde: sem bônus.
    final worse = controller.completeSession(module: 'phonemic', threshold: 14, duration: const Duration(minutes: 10));
    expect(worse.newBest, isFalse);
    expect(worse.points, 100);
    expect(controller.trainingPoints, first.points + noise.points + worse.points);
  });

  test('nível vem do limiar salvo da escada, não dos pontos', () {
    expect(controller.levelOf(TrainingId.phonemic), isNull);
    controller.saveTrainingState('phonemic', {'value': 8.0, 'threshold': 9.0});
    expect(controller.levelOf(TrainingId.phonemic), ProgressRules.phonemicLevel(9));
    controller.completeSession(module: 'phonemic', threshold: 9, duration: const Duration(minutes: 60));
    expect(controller.levelOf(TrainingId.phonemic), ProgressRules.phonemicLevel(9)); // pontos não mudam o nível
  });

  test('salvar e restaurar mantém pontos, níveis e recorde; logout zera tudo', () {
    controller.saveTrainingState('cocktail', {'value': -2.0, 'threshold': -1.5});
    controller.completeSession(module: 'cocktail', threshold: -1.5, duration: const Duration(minutes: 5));
    final saved = controller.toMapForSupabase();

    controller.resetForNewUser();
    expect(controller.trainingPoints, 0);
    expect(controller.trainingState('cocktail'), isNull);

    controller.fromMap(saved);
    expect(controller.trainingState('cocktail')!['value'], -2.0);
    expect(controller.trainingState('cocktail')!['best'], -1.5);
    expect(controller.trainingPoints, greaterThan(0));

    // Dados antigos (energia, nível de acuidade, SNR) são lidos sem erro e ignorados.
    controller.fromMap({'total_xp': 10, 'neural_energy': 3, 'acuity_level': 'ADVANCED', 'max_noise_threshold': -4});
    expect(controller.trainingPoints, 10);
  });
}
