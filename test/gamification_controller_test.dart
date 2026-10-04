import 'package:ear_training/core/gamification_controller.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _audiogram(int thresholdDb) => [
      for (final frequency in [2000, 3000, 4000, 6000, 8000])
        {'frequency': frequency, 'threshold': thresholdDb},
    ];

void main() {
  final controller = GamificationController();

  test('nunca sorteia itens placeholder (Palavra1/Falsa1)', () {
    // Perda em toda a faixa (filtro por frequência) e sem perda (sorteio geral).
    for (final threshold in [60, 0]) {
      for (var i = 0; i < 300; i++) {
        final phoneme = controller.getSmartPhoneme(_audiogram(threshold))!;
        expect(phoneme['type'], isNot('random_rehab'));
        expect(phoneme['target'] as String, isNot(startsWith('Palavra')));
      }
    }
  });

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
