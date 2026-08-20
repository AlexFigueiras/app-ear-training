import 'package:flutter_test/flutter_test.dart';
import 'package:ear_training/core/gamification_controller.dart';

void main() {
  group('GamificationController Tests', () {
    test('Initial state of neural energy and XP', () {
      final controller = GamificationController();
      controller.resetEnergy();
      expect(controller.neuralEnergy, 5);
      expect(controller.hasEnergy, isTrue);
      expect(controller.remainingRestTime, Duration.zero);
    });

    test('Consuming energy reduces count and calculates rest time', () {
      final controller = GamificationController();
      controller.resetEnergy();
      for (int i = 0; i < 5; i++) {
        controller.consumeEnergy();
      }
      expect(controller.neuralEnergy, 0);
      expect(controller.hasEnergy, isFalse);
      expect(controller.remainingRestTime.inMinutes, greaterThan(0));
    });
  });
}

