import 'dart:math' as math;

import '../models/audiogram.dart';

/// Ganhos do EQ por orelha, em dB, nas 8 bandas do motor (`cpp/eq_bank.h`).
///
/// Regras:
/// - **Por orelha:** a média esquerda/direita antiga sumia com perdas assimétricas.
/// - **Relativo à melhor frequência da orelha:** sem calibração do fone, os níveis do teste
///   são relativos. O que se sabe é o formato da perda, não o dB HL absoluto.
/// - **Meio ganho** (perda relativa ÷ 2), com teto de [maxGainDb].
/// - Frequências não medidas (3k, 6k nos audiogramas antigos) são interpoladas em escala log.
class AudibilityProfile {
  static const List<int> bands = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000];
  static const double maxGainDb = 25.0;

  /// Boost de dificuldade só nas bandas agudas (>= 3 kHz), onde estão as pistas de /s/, /f/, /t/.
  static const int highBandFromHz = 3000;
  static const double maxBoostDb = 24.0;

  final List<double> left;
  final List<double> right;

  const AudibilityProfile(this.left, this.right);

  static final AudibilityProfile flat =
      AudibilityProfile(List.filled(bands.length, 0.0), List.filled(bands.length, 0.0));

  factory AudibilityProfile.fromAudiogram(Audiogram audiogram) => AudibilityProfile(
        _earGains(audiogram.leftEar),
        _earGains(audiogram.rightEar),
      );

  /// Mesmo perfil com [boostDb] somado nas bandas agudas.
  AudibilityProfile withHighBandBoost(double boostDb) {
    final boost = boostDb.clamp(0.0, maxBoostDb);
    List<double> apply(List<double> gains) => [
          for (var i = 0; i < bands.length; i++)
            bands[i] >= highBandFromHz ? gains[i] + boost : gains[i],
        ];
    return AudibilityProfile(apply(left), apply(right));
  }

  static List<double> _earGains(List<AudiometryPoint> points) {
    final air = points.where((p) => p.conduction == ConductionType.air).toList()
      ..sort((a, b) => a.frequency.compareTo(b.frequency));
    if (air.isEmpty) return List.filled(bands.length, 0.0);

    final thresholds = [for (final f in bands) _interpolate(air, f)];
    final best = thresholds.reduce(math.min);
    return [
      for (final t in thresholds) ((t - best) / 2.0).clamp(0.0, maxGainDb),
    ];
  }

  /// Limiar em [freq] por interpolação linear em log2(frequência); fora da faixa medida,
  /// repete o ponto mais próximo.
  static double _interpolate(List<AudiometryPoint> sorted, int freq) {
    if (freq <= sorted.first.frequency) return sorted.first.threshold;
    if (freq >= sorted.last.frequency) return sorted.last.threshold;
    for (var i = 1; i < sorted.length; i++) {
      final hi = sorted[i];
      if (freq <= hi.frequency) {
        final lo = sorted[i - 1];
        final span = _log2(hi.frequency / lo.frequency);
        final pos = span == 0 ? 0.0 : _log2(freq / lo.frequency) / span;
        return lo.threshold + (hi.threshold - lo.threshold) * pos;
      }
    }
    return sorted.last.threshold;
  }

  static double _log2(num x) => math.log(x) / math.ln2;
}
