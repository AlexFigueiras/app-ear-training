import 'dart:math' as math;

import 'package:ear_training/models/rehab_session.dart';
import 'package:ear_training/training/digits_in_noise.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ouvinte simulado: acerta o trio com probabilidade logística em torno do SRT verdadeiro.
double _run(double trueSrt, math.Random random) {
  final din = DinProcedure(random: random);
  while (!din.isDone) {
    final t = din.next();
    final ok = random.nextDouble() < 1 / (1 + math.exp(-(t.snrDb - trueSrt) / 1.2));
    din.respond(ok ? t.digits : [t.digits[0], t.digits[1], (t.digits[2] + 1) % 10]);
  }
  return din.srt!;
}

RehabSession _session(RehabLevel level, DateTime date) => RehabSession(
    patientId: 'p', date: date, level: level, totalTrials: 24, correctAnswers: 12, averageResponseTimeMs: 0);

void main() {
  test('SRT sem viés (média a ±0,5 dB do verdadeiro) e dispersão de ~0,6 dB', () {
    final random = math.Random(3);
    for (final trueSrt in [-8.0, -3.0, 2.0]) {
      final estimates = [for (var i = 0; i < 1000; i++) _run(trueSrt, random)];
      final mean = estimates.reduce((a, b) => a + b) / estimates.length;
      expect(mean, closeTo(trueSrt, 0.5), reason: 'SRT verdadeiro $trueSrt');
    }
  });

  test('trios de 3 dígitos distintos, nunca iguais ao anterior; 24 trios', () {
    final din = DinProcedure(random: math.Random(4));
    List<int>? previous;
    var count = 0;
    while (!din.isDone) {
      final t = din.next();
      expect(t.digits.toSet().length, 3);
      expect(t.digits.every((d) => d >= 0 && d <= 9), isTrue);
      expect(previous != null && previous.join() == t.digits.join(), isFalse);
      previous = t.digits;
      din.respond(t.digits);
      count++;
    }
    expect(count, DinProcedure.totalTriplets);
    expect(din.correctTriplets, 24);
  });

  test('acerto só com os 3 dígitos certos na ordem; 1-acima/1-abaixo de 2 dB', () {
    final din = DinProcedure(random: math.Random(5));
    final t = din.next();
    expect(din.respond(t.digits.reversed.toList()), t.digits.reversed.join() == t.digits.join());
    expect(din.currentSnr, 2); // errou: +2 dB
    final t2 = din.next();
    expect(din.respond(t2.digits), isTrue);
    expect(din.currentSnr, 0); // acertou: -2 dB
    expect(din.srt, isNull); // só no fim
  });

  test('é hora de medir: nunca mediu ou última medida há 14 dias ou mais', () {
    final now = DateTime(2026, 10, 20);
    expect(DinProcedure.isDue([], now: now), isTrue);
    expect(DinProcedure.isDue([_session(RehabLevel.phonemicDiscrimination, DateTime(2026, 10, 19))], now: now), isTrue);
    expect(DinProcedure.isDue([_session(RehabLevel.digitsInNoise, DateTime(2026, 10, 10))], now: now), isFalse);
    expect(DinProcedure.isDue([_session(RehabLevel.digitsInNoise, DateTime(2026, 10, 6))], now: now), isTrue);
  });

  test('resultado em linguagem comum', () {
    expect(DinProcedure.describe(-4.5), contains('ruído 4,5 dB mais alto que a voz'));
    expect(DinProcedure.describe(3), contains('3,0 dB mais baixo'));
    expect(DinProcedure.describe(0.2), contains('tão alto quanto a voz'));
  });
}
