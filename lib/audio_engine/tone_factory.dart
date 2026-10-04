import 'dart:math' as math;
import 'dart:typed_data';

/// Geração de tons puros para teste e calibração.
///
/// Todo tom tem rampa cosseno de entrada e saída. Um seno que começa e termina de forma abrupta
/// produz um clique de banda larga: no teste de limiar, o paciente "ouvia" um tom de 8 kHz pela
/// energia grave do clique, e o limiar saía melhor do que é.
class ToneFactory {
  const ToneFactory._();

  /// Duração da rampa (padrão de audiometria: 20–50 ms).
  static const double rampSeconds = 0.020;

  /// Amplitude do tom de calibração/onboarding: -20 dBFS.
  static const double calibrationAmplitude = 0.1;

  static Float32List sine({
    required double frequencyHz,
    required double seconds,
    required double amplitude,
    double sampleRate = 48000.0,
  }) {
    final n = (seconds * sampleRate).round();
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = amplitude * math.sin(2 * math.pi * frequencyHz * i / sampleRate);
    }
    applyRamps(out, sampleRate: sampleRate);
    return out;
  }

  /// Tom pulsado do teste de limiar: [pulses] bipes de [onSeconds] separados por [offSeconds],
  /// cada um com rampa. Bipes são mais fáceis de notar perto do limiar e de separar de um
  /// zumbido (tinnitus) do que um tom contínuo.
  static Float32List pulsed({
    required double frequencyHz,
    required double amplitude,
    int pulses = 3,
    double onSeconds = 0.25,
    double offSeconds = 0.2,
    double sampleRate = 48000.0,
  }) {
    final on = sine(frequencyHz: frequencyHz, seconds: onSeconds, amplitude: amplitude, sampleRate: sampleRate);
    final gap = (offSeconds * sampleRate).round();
    final out = Float32List(pulses * on.length + (pulses - 1) * gap);
    for (var p = 0; p < pulses; p++) {
      out.setAll(p * (on.length + gap), on);
    }
    return out;
  }

  /// Aplica rampa cosseno elevado nas duas pontas (no máximo metade do sinal cada).
  static void applyRamps(Float32List samples, {double sampleRate = 48000.0}) {
    final ramp = math.min((rampSeconds * sampleRate).round(), samples.length ~/ 2);
    for (var i = 0; i < ramp; i++) {
      final g = 0.5 - 0.5 * math.cos(math.pi * i / ramp);
      samples[i] *= g;
      samples[samples.length - 1 - i] *= g;
    }
  }
}
