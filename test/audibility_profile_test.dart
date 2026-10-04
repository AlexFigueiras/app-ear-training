import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ear_training/audio_engine/audibility_profile.dart';
import 'package:ear_training/audio_engine/signal_level.dart';
import 'package:ear_training/models/audiogram.dart';
import 'package:flutter_test/flutter_test.dart';

List<AudiometryPoint> _ear(Map<int, double> thresholds) => [
      for (final e in thresholds.entries) AudiometryPoint(frequency: e.key, threshold: e.value),
    ];

Audiogram _audiogram(Map<int, double> left, Map<int, double> right) => Audiogram(
      id: 't',
      patientId: 'p',
      date: DateTime(2026),
      leftEar: _ear(left),
      rightEar: _ear(right),
    );

void main() {
  // Formato do teste antigo: sem 3k e 6k, ordem de teste (não ordenada).
  const sloping = {1000: 20.0, 2000: 30.0, 4000: 50.0, 8000: 70.0, 500: 15.0, 250: 15.0};

  test('ganho é meio-ganho da perda relativa à melhor frequência da orelha', () {
    final profile = AudibilityProfile.fromAudiogram(_audiogram(sloping, sloping));
    // Melhor = 15 dB. 2k: (30-15)/2 = 7,5. 4k: (50-15)/2 = 17,5. 8k: (70-15)/2 = 27,5 -> teto 25.
    expect(profile.left[0], 0.0); // 250
    expect(profile.left[3], closeTo(7.5, 1e-9)); // 2k
    expect(profile.left[5], closeTo(17.5, 1e-9)); // 4k
    expect(profile.left[7], AudibilityProfile.maxGainDb); // 8k no teto
  });

  test('3 kHz e 6 kHz não medidos são interpolados em escala log', () {
    final profile = AudibilityProfile.fromAudiogram(_audiogram(sloping, sloping));
    // 3k entre 2k (30) e 4k (50): log2(1,5) = 0,585 -> 41,7 dB -> ganho (41,7-15)/2 = 13,35.
    expect(profile.left[4], closeTo(13.35, 0.05));
    // 6k entre 4k (50) e 8k (70): log2(1,5) = 0,585 -> 61,7 dB -> ganho 23,35.
    expect(profile.left[6], closeTo(23.35, 0.05));
  });

  test('orelhas assimétricas não são mais misturadas pela média', () {
    final profile = AudibilityProfile.fromAudiogram(_audiogram(
      {250: 10, 500: 10, 1000: 10, 2000: 10, 4000: 10, 8000: 10},
      {250: 10, 500: 10, 1000: 10, 2000: 30, 4000: 50, 8000: 50},
    ));
    expect(profile.left.every((g) => g == 0.0), isTrue);
    expect(profile.right[5], closeTo(20.0, 1e-9));
  });

  test('orelha sem dados recebe EQ plano', () {
    final profile = AudibilityProfile.fromAudiogram(_audiogram(sloping, {}));
    expect(profile.right.every((g) => g == 0.0), isTrue);
  });

  test('boost de dificuldade só nas bandas >= 3 kHz e com teto', () {
    final boosted = AudibilityProfile.flat.withHighBandBoost(12);
    for (var i = 0; i < AudibilityProfile.bands.length; i++) {
      final expected = AudibilityProfile.bands[i] >= 3000 ? 12.0 : 0.0;
      expect(boosted.left[i], expected);
      expect(boosted.right[i], expected);
    }
    expect(AudibilityProfile.flat.withHighBandBoost(99).left.last, AudibilityProfile.maxBoostDb);
    expect(AudibilityProfile.flat.withHighBandBoost(-5).left.last, 0.0);
  });

  test('fala é normalizada para o RMS-alvo e o ruído sai no SNR pedido', () {
    final word = Float32List.fromList(
        [for (var i = 0; i < 4800; i++) 0.4 * math.sin(2 * math.pi * 300 * i / 48000)]);
    final normalized = SignalLevel.normalizeRms(word);
    expect(SignalLevel.rms(normalized), closeTo(SignalLevel.speechRms, 1e-6));
    expect(SignalLevel.rms(word), closeTo(0.4 / math.sqrt2, 1e-3)); // original intacto

    // Ruído uniforme [-a, a] tem RMS a/√3: em SNR 0 dB, o RMS do ruído = RMS da fala.
    final a0 = SignalLevel.whiteNoiseAmplitudeForSnr(0);
    expect(a0 / math.sqrt(3), closeTo(SignalLevel.speechRms, 1e-9));
    // -10 dB: ruído 10 dB acima da fala (antes ficava travado igual a 0 dB).
    final a10 = SignalLevel.whiteNoiseAmplitudeForSnr(-10);
    expect(20 * math.log(a10 / a0) / math.ln10, closeTo(10, 1e-9));
    expect(SignalLevel.normalizeRms(Float32List(10)).every((s) => s == 0), isTrue);
  });
}
