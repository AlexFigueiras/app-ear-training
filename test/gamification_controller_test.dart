import 'package:ear_training/core/gamification_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final controller = GamificationController();

  test(
      'resetForNewUser não deixa o próximo usuário herdar o estado do anterior',
      () {
    controller.addAcuityXP(1.0, ['s', 'cocktail']);
    controller.updateStreak(7);
    controller.setSessionsCompletedToday(2);

    controller.resetForNewUser();

    expect(controller.totalXP, 0);
    expect(controller.currentStreak, 0);
    expect(controller.sessionsCompletedToday, 0);
    expect(controller.acuityLevel, 'INITIAL');
    expect(controller.currentSNR, 20.0);
  });

  test('estado das escadas é salvo, restaurado e zerado no logout', () {
    controller.saveTrainingState('cocktail', {'value': -2.0, 'threshold': -1.5});
    final saved = controller.toMapForSupabase();
    controller.resetForNewUser();
    expect(controller.trainingState('cocktail'), isNull);
    controller.fromMap(saved);
    expect(controller.trainingState('cocktail')!['value'], -2.0);
    // Dado antigo com energia neural continua sendo lido sem erro.
    controller.fromMap({'total_xp': 10, 'neural_energy': 3});
    expect(controller.totalXP, 10);
  });
}
