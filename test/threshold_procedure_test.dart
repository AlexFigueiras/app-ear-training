import 'dart:math' as math;

import 'package:ear_training/training/threshold_procedure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ouvinte simulado: função psicométrica logística em torno do limiar verdadeiro e uma taxa de
/// "ouvi" em tentativas silenciosas (falso alarme).
class _Listener {
  final double threshold;
  final double slopeDb;
  final double falseAlarmRate;
  final math.Random random;

  _Listener(this.threshold, this.random, {this.slopeDb = 1.5, this.falseAlarmRate = 0.0});

  bool hears(Presentation p) {
    if (p.isCatch) return random.nextDouble() < falseAlarmRate;
    final probability = 1 / (1 + math.exp(-(p.level - threshold) / slopeDb));
    return random.nextDouble() < probability;
  }
}

FrequencyResult _run(ThresholdProcedure procedure, bool Function(Presentation) answer) {
  var guard = 0;
  while (!procedure.isDone) {
    procedure.respond(answer(procedure.next()));
    if (++guard > 500) fail('procedimento não terminou (laço infinito)');
  }
  return procedure.result!;
}

void main() {
  // Precisão do método (passos de 5 dB, como na audiometria clínica), medida em simulação com
  // limiares uniformes em [-5, 65] dB e inclinação psicométrica realista: ~80% a ±5 dB, ~100% a
  // ±10 dB, erro médio ~3 dB e viés de ~+2,7 dB (o Hughson-Westlake estima perto do ponto de 70%
  // de detecção, não do de 50%). O teste trava esses números para regressões não passarem.
  test('precisão: ≥75% a ±5 dB, ≥99% a ±10 dB, erro médio ≤3,5 dB, viés entre 0 e +4 dB', () {
    final random = math.Random(42);
    const runs = 3000;
    var within5 = 0, within10 = 0;
    var sumAbs = 0.0, sumError = 0.0;
    for (var i = 0; i < runs; i++) {
      final trueThreshold = -5 + random.nextDouble() * 70;
      final listener = _Listener(trueThreshold, random, slopeDb: 2.0, falseAlarmRate: 0.03);
      final result = _run(ThresholdProcedure(random: random), listener.hears);
      final error = result.threshold - trueThreshold;
      if (error.abs() <= 5) within5++;
      if (error.abs() <= 10) within10++;
      sumAbs += error.abs();
      sumError += error;
    }
    expect(within5 / runs, greaterThanOrEqualTo(0.75));
    expect(within10 / runs, greaterThanOrEqualTo(0.99));
    expect(sumAbs / runs, lessThanOrEqualTo(3.5));
    expect(sumError / runs, inInclusiveRange(0.0, 4.0));
  });

  test('"sempre ouvi" (chute) é detectado pelas tentativas silenciosas e não trava no piso', () {
    final random = math.Random(7);
    var unreliable = 0;
    for (var i = 0; i < 200; i++) {
      final result = _run(ThresholdProcedure(random: random), (_) => true);
      if (!result.reliable) unreliable++;
      expect(result.presentations, lessThanOrEqualTo(30));
    }
    // Com ~20% de silenciosas e 4 falsos alarmes para encerrar, quase toda execução é marcada.
    expect(unreliable / 200, greaterThan(0.6));
  });

  test('"sempre não ouvi" termina como "sem resposta" no nível máximo (não sobe até 120)', () {
    final result = _run(ThresholdProcedure(random: math.Random(1)), (_) => false);
    expect(result.noResponse, isTrue);
    expect(result.threshold, 80);
    expect(result.presentations, lessThan(10));
  });

  test('ouvir no piso conta como resposta ascendente e encerra em -10', () {
    final result = _run(
        ThresholdProcedure(random: math.Random(3), catchProbability: 0), (p) => !p.isCatch);
    expect(result.threshold, -10);
    expect(result.noResponse, isFalse);
  });

  test('familiarização sem silenciosas; limiar só é aceito depois de 2 silenciosas', () {
    final random = math.Random(11);
    final listener = _Listener(30, random);
    for (var run = 0; run < 200; run++) {
      final procedure = ThresholdProcedure(random: random, catchProbability: 0.0);
      expect(procedure.next().isCatch, isFalse); // familiarização
      procedure.respond(true);
      var catches = 0;
      while (!procedure.isDone) {
        final p = procedure.next();
        if (p.isCatch) catches++;
        procedure.respond(listener.hears(p));
      }
      // Mesmo sem silenciosas aleatórias, a verificação final apresenta 2.
      expect(catches, greaterThanOrEqualTo(ThresholdProcedure.minVerificationCatches));
    }
  });

  test('2 falsos alarmes reiniciam a frequência e avisam a tela', () {
    // Toda apresentação possível é silenciosa; quem responde "ouvi" sempre faz falsos alarmes.
    final procedure = ThresholdProcedure(random: math.Random(5), catchProbability: 1.0);
    var restarts = 0;
    var guard = 0;
    while (!procedure.isDone && guard++ < 100) {
      procedure.next();
      procedure.respond(true);
      if (procedure.restartedForFalseAlarms) restarts++;
    }
    expect(restarts, greaterThanOrEqualTo(1));
    expect(procedure.isDone, isTrue);
    expect(procedure.result!.reliable, isFalse); // 4 falsos alarmes encerram como duvidoso
  });
}
