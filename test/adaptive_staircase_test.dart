import 'dart:math' as math;

import 'package:ear_training/training/adaptive_staircase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ouvinte simulado de escolha forçada: p(acerto) = chance + (1 - chance)·logística((v - 0)/s).
/// Valor maior = mais fácil (SNR maior / mais reforço).
double _pCorrect(double v, double chance, double slope) => chance + (1 - chance) / (1 + math.exp(-v / slope));

/// Ponto de 79,4% da função (alvo teórico da escada 3-acertos/1-erro), por bisseção.
double _target(double chance, double slope) {
  var lo = -30.0, hi = 30.0;
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (_pCorrect(mid, chance, slope) < 0.794) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

void main() {
  test('converge para o ponto de ~79% de acerto (2 e 4 opções), a ±1,5 dB em média', () {
    final random = math.Random(1);
    for (final chance in [0.5, 0.25]) {
      const slope = 2.0;
      final target = _target(chance, slope);
      var sum = 0.0;
      const runs = 500;
      for (var run = 0; run < runs; run++) {
        final s = AdaptiveStaircase(start: 12, minValue: -20, maxValue: 24);
        for (var i = 0; i < 60; i++) {
          s.record(correct: random.nextDouble() < _pCorrect(s.value, chance, slope));
        }
        sum += s.threshold!;
      }
      expect(sum / runs, closeTo(target, 1.5), reason: 'chance $chance');
    }
  });

  test('3 acertos dificultam, 1 erro facilita; passo grande vira pequeno após 2 reversões', () {
    final s = AdaptiveStaircase(start: 10, minValue: -20, maxValue: 20);
    s.record(correct: true);
    s.record(correct: true);
    expect(s.value, 10); // ainda não
    s.record(correct: true);
    expect(s.value, 6); // -4 (passo grande)
    s.record(correct: false);
    expect(s.value, 10); // reversão 1
    for (var i = 0; i < 3; i++) {
      s.record(correct: true);
    }
    expect(s.value, 8); // reversão 2: a partir daqui, passo pequeno (-2)
    s.record(correct: false);
    expect(s.value, 10); // reversão 3 (+2)
    expect(s.reversals.length, 3);
  });

  test('respeita os limites e só estima o limiar com reversões suficientes', () {
    final s = AdaptiveStaircase(start: 0, minValue: 0, maxValue: 6);
    expect(s.threshold, isNull);
    for (var i = 0; i < 30; i++) {
      s.record(correct: true);
    }
    expect(s.value, 0);
    for (var i = 0; i < 10; i++) {
      s.record(correct: false);
    }
    expect(s.value, 6);
  });

  test('retoma de onde parou, 4 dB mais fácil; primeira vez começa no início', () {
    final first = AdaptiveStaircase.resume(null, start: 10, minValue: -15, maxValue: 20);
    expect(first.value, 10);
    final resumed = AdaptiveStaircase.resume({'value': -3.0, 'threshold': -2.0, 'trials': 80},
        start: 10, minValue: -15, maxValue: 20);
    expect(resumed.value, 1);
    expect(AdaptiveStaircase(start: 5, minValue: 0, maxValue: 10).toJson()['value'], 5);
  });

  test('relógio da sessão: termina em 10 minutos e informa os minutos restantes', () {
    var now = DateTime(2026, 10, 4, 10);
    final clock = SessionClock(now: () => now);
    expect(clock.isOver, isFalse);
    expect(clock.minutesLeft, 10);
    now = now.add(const Duration(minutes: 7, seconds: 30));
    expect(clock.progress, closeTo(0.75, 1e-9));
    expect(clock.minutesLeft, 3);
    now = now.add(const Duration(minutes: 3));
    expect(clock.isOver, isTrue);
    expect(clock.progress, 1.0);
  });
}
