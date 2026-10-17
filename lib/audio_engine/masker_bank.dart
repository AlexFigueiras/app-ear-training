import 'dart:math' as math;
import 'dart:typed_data';

import 'signal_level.dart';

/// Tipo de ruído do treino "Conversa no barulho".
enum MaskerType {
  /// Ruído com o espectro médio da fala: mascara de forma estável (mais fácil).
  speechShaped,

  /// Burburinho de 6 vozes falando ao mesmo tempo: o ruído de restaurante de verdade, que
  /// também "compete" pela atenção (mais difícil).
  babble,
}

/// Geração dos ruídos de fundo. Substitui o ruído branco, que mascarava desproporcionalmente os
/// agudos (espectro plano) e não parecia com nenhum ambiente real; os rótulos antigos
/// "RESTAURANTE/TRÁFEGO/VENTO" não correspondiam ao som.
///
/// Todo ruído sai com RMS = [SignalLevel.speechRms], igual à fala normalizada. Assim o SNR é só o
/// ganho do ruído: ganho = 10^(-SNR/20) ([SignalLevel.maskerGainForSnr]).
class MaskerBank {
  const MaskerBank._();

  static const double sampleRate = 48000;
  static const double loopSeconds = 6;
  static const double crossfadeSeconds = 0.05;

  /// Frases neutras para o burburinho (3 vozes × 2 frases = 6 falantes).
  static const List<String> babbleSentences = [
    'O menino comprou pão na padaria da esquina.',
    'Amanhã vai chover bastante no fim da tarde.',
    'Ela guardou as chaves dentro da bolsa azul.',
    'Nós vamos visitar a minha avó no domingo.',
    'O ônibus atrasou por causa do trânsito da avenida.',
    'Você pode fechar a janela da sala, por favor?',
  ];

  /// Ruído branco filtrado para o espectro médio da fala: passa-alta em ~100 Hz, plano até
  /// ~500 Hz, -6 dB/oitava até ~4 kHz e -12 dB/oitava acima (aproximação da LTASS de Byrne et
  /// al., 1994).
  static Float32List speechShapedNoise({math.Random? random}) {
    final rng = random ?? math.Random();
    final n = (loopSeconds * sampleRate).round();
    final out = Float32List(n);
    double onePole(double fc) => math.exp(-2 * math.pi * fc / sampleRate);
    final a500 = onePole(500), a4k = onePole(4000), a100 = onePole(100);
    var lp500 = 0.0, lp4k = 0.0, hpState = 0.0;
    for (var i = 0; i < n; i++) {
      final white = rng.nextDouble() * 2 - 1;
      lp500 = (1 - a500) * white + a500 * lp500;
      lp4k = (1 - a4k) * lp500 + a4k * lp4k;
      hpState = (1 - a100) * lp4k + a100 * hpState;
      out[i] = lp4k - hpState; // remove o que está abaixo de ~100 Hz
    }
    return SignalLevel.normalizeRms(loopCrossfade(out));
  }

  /// Burburinho: cada falante normalizado, repetido até a duração do loop e deslocado no tempo
  /// (para as frases não começarem juntas), somados e normalizados.
  static Float32List babble(List<Float32List> talkers) {
    final n = (loopSeconds * sampleRate).round();
    final mix = Float32List(n);
    final usable = talkers.where((t) => t.isNotEmpty).toList();
    for (var t = 0; t < usable.length; t++) {
      final voice = SignalLevel.normalizeRms(usable[t]);
      final offset = t * n ~/ usable.length;
      for (var i = 0; i < n; i++) {
        mix[i] += voice[(i + offset) % voice.length];
      }
    }
    return SignalLevel.normalizeRms(loopCrossfade(mix));
  }

  /// Emenda de loop sem clique: o fim do sinal é misturado ao começo em [crossfadeSeconds].
  /// O resultado é [crossfadeSeconds] mais curto e a última amostra emenda na primeira.
  static Float32List loopCrossfade(Float32List x) {
    final fade = math.min((crossfadeSeconds * sampleRate).round(), x.length ~/ 2);
    final out = Float32List(x.length - fade);
    for (var i = 0; i < out.length; i++) {
      if (i < fade) {
        final g = i / fade;
        out[i] = x[i] * g + x[x.length - fade + i] * (1 - g);
      } else {
        out[i] = x[i];
      }
    }
    return out;
  }
}
