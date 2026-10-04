import 'dart:math' as math;

import 'package:ear_training/models/audiogram.dart';
import 'package:ear_training/training/hearing_summary.dart';
import 'package:ear_training/training/hearing_test_session.dart';
import 'package:ear_training/training/threshold_procedure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ouvinte determinístico: ouve tudo a partir do limiar da frequência (sem falso alarme).
bool Function(HearingTestSession, Presentation) _listener(Map<int, double> left, Map<int, double> right) =>
    (session, p) {
      if (p.isCatch) return false;
      final step = session.currentStep;
      final t = (step.ear == EarSide.left ? left : right)[step.frequency]!;
      return p.level >= t;
    };

void _runAll(HearingTestSession session, bool Function(HearingTestSession, Presentation) hears) {
  var guard = 0;
  while (!session.isDone) {
    final p = session.next();
    session.respond(hears(session, p));
    if (++guard > 5000) fail('sessão não terminou');
  }
}

const _sloping = {250: 10.0, 500: 10.0, 1000: 15.0, 2000: 25.0, 3000: 35.0, 4000: 45.0, 6000: 55.0, 8000: 60.0};

void main() {
  test('ordem clínica, uma orelha de cada vez, com 3 k, 6 k e reteste de 1 kHz', () {
    final session = HearingTestSession(random: math.Random(1));
    final freqs = session.steps.map((s) => s.frequency).toList();
    expect(freqs.sublist(0, 9).join(','), '1000,2000,3000,4000,6000,8000,1000,500,250');
    expect(session.steps.take(9).every((s) => s.ear == EarSide.left), isTrue);
    expect(session.steps.skip(9).every((s) => s.ear == EarSide.right), isTrue);
    expect(session.steps.where((s) => s.isRetest).length, 2);
  });

  test('resultado em ordem crescente, com protocolo 2, perto do limiar simulado', () {
    final session = HearingTestSession(random: math.Random(2));
    var earStarts = 0;
    var guard = 0;
    final hears = _listener(_sloping, _sloping);
    while (!session.isDone && guard++ < 5000) {
      if (session.atEarStart) earStarts++;
      final p = session.next();
      session.respond(hears(session, p));
    }
    expect(earStarts, greaterThanOrEqualTo(2)); // a tela avisa ao começar cada orelha
    final points = session.pointsFor(EarSide.left);
    expect(points.map((p) => p.frequency).join(','), '250,500,1000,2000,3000,4000,6000,8000');
    for (final p in points) {
      expect(p.protocol, AudiometryPoint.currentProtocol);
      expect(p.threshold - _sloping[p.frequency]!, inInclusiveRange(0, 5));
      expect(p.reliable, isTrue);
    }
  });

  test('reteste de 1 kHz inconsistente marca a orelha como duvidosa', () {
    var firstOneK = true;
    final session = HearingTestSession(random: math.Random(3));
    _runAll(session, (s, p) {
      if (p.isCatch) return false;
      final step = s.currentStep;
      if (step.ear == EarSide.left && step.frequency == 1000 && !step.isRetest) firstOneK = true;
      if (step.ear == EarSide.left && step.isRetest) firstOneK = false;
      // 1ª medida de 1 kHz em 10 dB; reteste em 40 dB: diferença de 30 dB.
      final t = step.frequency == 1000 && step.ear == EarSide.left ? (firstOneK ? 10.0 : 40.0) : 20.0;
      return p.level >= t;
    });
    expect(session.retestInconsistent(EarSide.left), isTrue);
    expect(session.pointsFor(EarSide.left).every((p) => !p.reliable), isTrue);
    expect(session.retestInconsistent(EarSide.right), isFalse);
  });

  test('categoria OMS aproximada e próximo passo', () {
    Audiogram audiogram(Map<int, double> left, Map<int, double> right) => Audiogram(
          id: '',
          patientId: '',
          date: DateTime(2026),
          leftEar: [for (final e in left.entries) AudiometryPoint(frequency: e.key, threshold: e.value, protocol: 2)],
          rightEar: [for (final e in right.entries) AudiometryPoint(frequency: e.key, threshold: e.value, protocol: 2)],
        );
    const normal = {250: 5.0, 500: 5.0, 1000: 5.0, 2000: 10.0, 3000: 10.0, 4000: 10.0, 6000: 15.0, 8000: 15.0};

    final ok = HearingTestAdvice(audiogram(normal, normal));
    expect(ok.left.category, 'Dentro do esperado');
    expect(ok.nextStep, NextStep.startTraining);

    final sloping = HearingTestAdvice(audiogram(_sloping, _sloping));
    // PTA4 = (10 + 15 + 25 + 45) / 4 = 23,75 -> leve; agudos (45+55+60)/3 = 53,3 -> perda em agudos.
    expect(sloping.left.category, 'Perda leve');
    expect(sloping.left.highFrequencyLoss, isTrue);
    expect(sloping.nextStep, NextStep.startTraining);

    final asymmetric = HearingTestAdvice(audiogram(normal, _sloping));
    expect(asymmetric.asymmetric, isTrue);
    expect(asymmetric.nextStep, NextStep.seeProfessional);
  });

  test('audiograma do teste antigo (sem protocolo) pede reteste; o novo não', () {
    final old = Audiogram.fromJson({
      'patient_id': 'p',
      'created_at': '2026-01-01T00:00:00Z',
      'left_ear': [
        {'frequency': 1000, 'threshold': 20, 'conduction': 'air', 'masked': false}
      ],
      'right_ear': [],
    });
    expect(old.isOutdated, isTrue);
    expect(old.leftEar.first.protocol, 1);

    final point = AudiometryPoint(frequency: 4000, threshold: 80, noResponse: true, protocol: 2);
    final back = AudiometryPoint.fromJson(point.toJson());
    expect(back.noResponse, isTrue);
    expect(back.protocol, 2);
    expect(Audiogram(id: '', patientId: '', date: DateTime(2026), leftEar: [back], rightEar: [back]).isOutdated,
        isFalse);
  });
}
