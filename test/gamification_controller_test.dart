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
    expect(controller.neuralEnergy, 5);
  });
}
