import 'dart:math' as math;
import 'dart:typed_data';

/// Medida e normalização de nível dos estímulos.
///
/// Toda palavra é levada ao mesmo RMS antes de tocar. Assim:
/// - a diferença entre palavras vem do conteúdo, não de como o TTS gravou cada uma;
/// - sobra headroom para o EQ e o limitador de segurança quase nunca age;
/// - o SNR do Coquetel é calculado sobre um nível de fala conhecido.
class SignalLevel {
  const SignalLevel._();

  /// RMS-alvo da fala: -30 dBFS.
  static const double speechRms = 0.0316;

  static double rms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  /// Cópia de [samples] com RMS = [targetRms]. Silêncio volta como silêncio.
  static Float32List normalizeRms(Float32List samples, {double targetRms = speechRms}) {
    final current = rms(samples);
    final out = Float32List.fromList(samples);
    if (current < 1e-9) return out;
    final gain = targetRms / current;
    for (var i = 0; i < out.length; i++) {
      out[i] *= gain;
    }
    return out;
  }

  /// Ganho linear do ruído para obter [snrDb]: fala e ruído saem com o mesmo RMS
  /// ([speechRms]), então SNR = -20·log10(ganho). Vale abaixo de 0 dB (ruído mais alto que a fala).
  static double maskerGainForSnr(double snrDb) => math.pow(10, -snrDb / 20).toDouble();
}
