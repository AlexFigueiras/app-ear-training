import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ear_training/audio_engine/masker_bank.dart';
import 'package:ear_training/audio_engine/signal_level.dart';
import 'package:flutter_test/flutter_test.dart';

/// Potência média numa frequência (Goertzel em janelas de 4096 amostras).
double _powerAt(Float32List x, double freq) {
  const window = 4096;
  var total = 0.0;
  var blocks = 0;
  final k = (window * freq / MaskerBank.sampleRate).round();
  final w = 2 * math.pi * k / window;
  final coeff = 2 * math.cos(w);
  for (var start = 0; start + window <= x.length; start += window) {
    var s1 = 0.0, s2 = 0.0;
    for (var i = 0; i < window; i++) {
      final s0 = x[start + i] + coeff * s1 - s2;
      s2 = s1;
      s1 = s0;
    }
    total += s1 * s1 + s2 * s2 - coeff * s1 * s2;
    blocks++;
  }
  return total / blocks;
}

double _db(double ratio) => 10 * math.log(ratio) / math.ln10;

void main() {
  test('ruído de fala: RMS da fala normalizada e espectro caindo para os agudos', () {
    final noise = MaskerBank.speechShapedNoise(random: math.Random(1));
    expect(SignalLevel.rms(noise), closeTo(SignalLevel.speechRms, 1e-4));
    // Espectro de fala: 4 kHz bem abaixo de 500 Hz (o ruído branco antigo era plano).
    expect(_db(_powerAt(noise, 500) / _powerAt(noise, 4000)), greaterThan(12));
    expect(_db(_powerAt(noise, 500) / _powerAt(noise, 8000)), greaterThan(_db(_powerAt(noise, 500) / _powerAt(noise, 4000))));
  });

  test('emenda de loop sem salto: a última amostra continua na primeira', () {
    final x = Float32List.fromList([for (var i = 0; i < 48000; i++) math.sin(2 * math.pi * 333.3 * i / 48000)]);
    final looped = MaskerBank.loopCrossfade(x);
    expect(looped.length, 48000 - 2400);
    var maxStep = 0.0;
    for (var i = 1; i < looped.length; i++) {
      maxStep = math.max(maxStep, (looped[i] - looped[i - 1]).abs());
    }
    final seam = (looped.first - looped.last).abs();
    expect(seam, lessThanOrEqualTo(maxStep * 1.5));
  });

  test('burburinho: mistura todos os falantes, RMS normalizado e 6 s de loop', () {
    final random = math.Random(2);
    final talkers = [
      for (var t = 0; t < 6; t++)
        Float32List.fromList([for (var i = 0; i < 24000 + t * 1000; i++) (random.nextDouble() * 2 - 1) * (t + 1) * 0.05]),
    ];
    final babble = MaskerBank.babble(talkers);
    expect(babble.length, (MaskerBank.loopSeconds * MaskerBank.sampleRate).round() - 2400);
    expect(SignalLevel.rms(babble), closeTo(SignalLevel.speechRms, 1e-4));
  });
}
