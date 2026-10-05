import 'dart:math' as math;

import 'package:ear_training/models/audiogram.dart';
import 'package:ear_training/training/item_selector.dart';
import 'package:ear_training/training/stimulus_bank.dart';
import 'package:flutter_test/flutter_test.dart';

Audiogram _audiogram(Map<int, double> thresholds) {
  List<AudiometryPoint> ear() => [
        for (final e in thresholds.entries) AudiometryPoint(frequency: e.key, threshold: e.value, protocol: 2),
      ];
  return Audiogram(id: '', patientId: '', date: DateTime(2026), leftEar: ear(), rightEar: ear());
}

const _sloping = {250: 10.0, 500: 10.0, 1000: 15.0, 2000: 25.0, 3000: 35.0, 4000: 45.0, 6000: 55.0, 8000: 60.0};

/// Palavras que já existiram no banco antigo como pseudopalavras ou placeholders.
const _forbidden = ['Felo', 'Fete', 'Fopa', 'Feda', 'Foma', 'Sosso', 'Pacho', 'Tedo', 'Xato', 'Chelo', 'Sero', 'Sona', 'Budo'];

void main() {
  test('banco: só palavras reais, pares distintos, contrastes agudos com vários itens', () {
    for (final p in StimulusBank.pairs) {
      expect(p.a == p.b, isFalse);
      expect(_forbidden.contains(p.a) || _forbidden.contains(p.b), isFalse);
      expect(p.a.startsWith('Palavra') || p.b.startsWith('Falsa'), isFalse);
    }
    final ids = StimulusBank.pairs.map((p) => p.id).toSet();
    expect(ids.length, StimulusBank.pairs.length);
    for (final c in Contrast.values) {
      expect(StimulusBank.of(c).length, greaterThanOrEqualTo(5));
    }
    // Vozeamento/nasalidade só no aquecimento.
    expect(StimulusBank.of(Contrast.warmUp).length, lessThan(StimulusBank.pairs.length ~/ 4));
  });

  test('qualquer palavra do par pode tocar (~50/50) e a resposta certa é a tocada', () {
    final selector = ItemSelector(audiogram: _audiogram(_sloping), random: math.Random(1), warmUpTrials: 0);
    var playedA = 0;
    const n = 2000;
    for (var i = 0; i < n; i++) {
      final t = selector.next();
      if (t.played == t.pair.a) playedA++;
      expect(t.options.toSet(), {t.pair.a, t.pair.b});
      expect(t.isCorrect(t.played), isTrue);
      expect(t.isCorrect(t.played == t.pair.a ? t.pair.b : t.pair.a), isFalse);
      expect(StimulusBank.voices.contains(t.voice), isTrue);
    }
    expect(playedA / n, closeTo(0.5, 0.05));
  });

  test('sem repetir o mesmo par nas últimas 4 tentativas; aquecimento só no início', () {
    final selector = ItemSelector(audiogram: _audiogram(_sloping), random: math.Random(2));
    final trials = [for (var i = 0; i < 300; i++) selector.next()];
    expect(trials.take(2).every((t) => t.pair.contrast == Contrast.warmUp), isTrue);
    expect(trials.skip(2).every((t) => t.pair.contrast.isHighFrequency), isTrue);
    for (var i = 1; i < trials.length; i++) {
      final window = trials.sublist(math.max(0, i - ItemSelector.recentWindow), i).map((t) => t.pair.id);
      expect(window.contains(trials[i].pair.id), isFalse);
    }
  });

  test('perda maior na faixa da pista e erros recentes aumentam o peso do contraste', () {
    final selector = ItemSelector(audiogram: _audiogram(_sloping), random: math.Random(3));
    // 6 kHz (s × f, plural) tem mais perda que 3 kHz (t × k) neste audiograma.
    expect(selector.weightOf(Contrast.sVsF), greaterThan(selector.weightOf(Contrast.tVsK)));

    final before = selector.weightOf(Contrast.tVsK);
    final trial = Trial(
        pair: StimulusBank.of(Contrast.tVsK).first, played: 'tola', voice: StimulusBank.voices.first, options: const ['tola', 'cola']);
    selector.record(trial, correct: false);
    expect(selector.weightOf(Contrast.tVsK), greaterThan(before));
  });

  test('guarda de audibilidade: contraste com pista inaudível sai do sorteio', () {
    // Perda severa só nos agudos extremos: pistas de 6 kHz inaudíveis, 3–4 kHz ainda audíveis.
    final selector = ItemSelector(
      audiogram: _audiogram({250: 10, 500: 10, 1000: 15, 2000: 25, 3000: 40, 4000: 55, 6000: 75, 8000: 80}),
      random: math.Random(4),
      warmUpTrials: 0,
    );
    expect(selector.inaudible, containsAll([Contrast.sVsF, Contrast.finalS]));
    expect(selector.nothingAudible, isFalse);
    for (var i = 0; i < 300; i++) {
      final c = selector.next().pair.contrast;
      expect(c == Contrast.sVsF || c == Contrast.finalS, isFalse);
    }

    // Nada agudo audível: o treino cai para o aquecimento (e a tela avisa).
    final none = ItemSelector(audiogram: _audiogram({250: 60, 500: 70, 1000: 75, 2000: 80, 4000: 80, 8000: 80}));
    expect(none.nothingAudible, isTrue);
    expect(none.next().pair.contrast, Contrast.warmUp);
  });

  test('Coquetel: 4 opções {sala, fala, salas, falas}, qualquer uma pode tocar', () {
    final selector = ItemSelector(audiogram: _audiogram(_sloping), random: math.Random(6), warmUpTrials: 0);
    final playedIndex = <int, int>{};
    for (var i = 0; i < 2000; i++) {
      final t = selector.nextQuad();
      expect(t.pair.pluralizable, isTrue);
      expect(t.options.toSet(), t.pair.quad.toSet());
      expect(t.options.contains(t.played), isTrue);
      final idx = t.pair.quad.indexOf(t.played);
      playedIndex[idx] = (playedIndex[idx] ?? 0) + 1;
    }
    for (var i = 0; i < 4; i++) {
      expect(playedIndex[i]! / 2000, closeTo(0.25, 0.04));
    }

    // /s/ final inaudível: volta para 2 opções.
    final noPlural = ItemSelector(
      audiogram: _audiogram({250: 10, 500: 10, 1000: 15, 2000: 25, 3000: 40, 4000: 55, 6000: 75, 8000: 80}),
      warmUpTrials: 0,
    );
    expect(noPlural.nextQuad().options.length, 2);
  });

  test('sem audiograma: pesos iguais e todos os contrastes agudos possíveis', () {
    final selector = ItemSelector(random: math.Random(5), warmUpTrials: 0);
    expect(selector.inaudible, isEmpty);
    final seen = {for (var i = 0; i < 500; i++) selector.next().pair.contrast};
    expect(seen.containsAll(Contrast.values.where((c) => c.isHighFrequency)), isTrue);
  });
}
