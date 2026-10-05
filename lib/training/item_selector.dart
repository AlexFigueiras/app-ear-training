import 'dart:math' as math;

import '../audio_engine/audibility_profile.dart';
import '../models/audiogram.dart';
import 'stimulus_bank.dart';

/// Uma tentativa: qual par, qual das duas palavras toca, em que voz e em que ordem aparecem.
class Trial {
  final MinimalPair pair;
  final String played;
  final String voice;
  final List<String> options;

  const Trial({required this.pair, required this.played, required this.voice, required this.options});

  bool isCorrect(String answer) => answer == played;
}

/// Escolhe as tentativas do treino de palavras parecidas.
///
/// - Qualquer palavra do par pode tocar (50/50): a resposta não é memorizável (achado D1).
/// - Começa com [warmUpTrials] itens de aquecimento (pistas graves); depois só contrastes agudos.
/// - Mais peso para contrastes cuja pista cai onde a pessoa tem mais perda, e para os que ela
///   errou há pouco.
/// - Não repete os últimos [recentWindow] pares.
/// - Guarda de audibilidade: contraste cuja pista está numa faixa que a melhor orelha não ouve
///   nem no volume máximo do teste ([inaudibleFromDb]) sai do sorteio. Treinar o que não chega
///   ao ouvido não cria a percepção; nesse caso o caminho é aparelho auditivo ou avaliação.
class ItemSelector {
  static const double inaudibleFromDb = 70;
  static const int recentWindow = 4;

  final Audiogram? audiogram;
  final int warmUpTrials;
  final math.Random _random;

  final Map<Contrast, double> _recentErrors = {};
  final List<String> _recentPairs = [];
  int _served = 0;

  ItemSelector({this.audiogram, this.warmUpTrials = 2, math.Random? random})
      : _random = random ?? math.Random();

  /// Limiar da melhor orelha na faixa da pista (null sem audiograma).
  double? betterEarThresholdAt(int freq) {
    final a = audiogram;
    if (a == null) return null;
    final values = [
      AudibilityProfile.thresholdAt(a.leftEar, freq),
      AudibilityProfile.thresholdAt(a.rightEar, freq),
    ].whereType<double>();
    return values.isEmpty ? null : values.reduce(math.min);
  }

  /// Contrastes agudos fora do alcance (pista inaudível mesmo no máximo).
  Set<Contrast> get inaudible => {
        for (final c in Contrast.values)
          if (c.isHighFrequency && (betterEarThresholdAt(c.cueBandHz) ?? 0) >= inaudibleFromDb) c,
      };

  /// Nenhum contraste agudo é audível: o treino não tem o que ensinar a esta pessoa.
  bool get nothingAudible => Contrast.values.where((c) => c.isHighFrequency).every(inaudible.contains);

  Trial next() {
    final contrast = _served < warmUpTrials || nothingAudible ? Contrast.warmUp : _pickContrast();
    final candidates = StimulusBank.of(contrast).where((p) => !_recentPairs.contains(p.id)).toList();
    final pool = candidates.isNotEmpty ? candidates : StimulusBank.of(contrast).toList();
    final pair = pool[_random.nextInt(pool.length)];

    _recentPairs.add(pair.id);
    if (_recentPairs.length > recentWindow) _recentPairs.removeAt(0);
    _served++;

    final options = [pair.a, pair.b]..shuffle(_random);
    return Trial(
      pair: pair,
      played: _random.nextBool() ? pair.a : pair.b,
      voice: StimulusBank.voices[_random.nextInt(StimulusBank.voices.length)],
      options: options,
    );
  }

  /// Coquetel: 4 opções {a, b, as, bs} (chance de 25%), tocando qualquer uma. Cai para 2 opções
  /// se o /s/ final for inaudível ou não houver par com plural audível.
  Trial nextQuad() {
    if (inaudible.contains(Contrast.finalS)) return next();
    final eligible = {
      for (final p in StimulusBank.pairs)
        if (p.pluralizable && !inaudible.contains(p.contrast)) p.contrast,
    };
    if (eligible.isEmpty) return next();
    final contrast = _pickContrast(only: eligible);
    final all = StimulusBank.of(contrast).where((p) => p.pluralizable).toList();
    final fresh = all.where((p) => !_recentPairs.contains(p.id)).toList();
    final pool = fresh.isNotEmpty ? fresh : all;
    final pair = pool[_random.nextInt(pool.length)];

    _recentPairs.add(pair.id);
    if (_recentPairs.length > recentWindow) _recentPairs.removeAt(0);
    _served++;

    final options = pair.quad..shuffle(_random);
    return Trial(
      pair: pair,
      played: options[_random.nextInt(options.length)],
      voice: StimulusBank.voices[_random.nextInt(StimulusBank.voices.length)],
      options: options,
    );
  }

  /// Erro aumenta o peso do contraste; acerto o reduz aos poucos.
  void record(Trial trial, {required bool correct}) {
    final c = trial.pair.contrast;
    final current = _recentErrors[c] ?? 0;
    _recentErrors[c] = correct ? math.max(0, current - 0.5) : math.min(3, current + 1);
  }

  /// Peso de um contraste: perda na faixa da pista (até 3×) × erros recentes (até 4×).
  double weightOf(Contrast c) {
    final best = _bestThreshold();
    final atCue = betterEarThresholdAt(c.cueBandHz);
    final lossWeight =
        best == null || atCue == null ? 1.0 : 1.0 + ((atCue - best) / 20).clamp(0.0, 2.0);
    return lossWeight * (1 + (_recentErrors[c] ?? 0));
  }

  /// Melhor limiar da melhor orelha em todas as bandas (referência da perda relativa).
  double? _bestThreshold() {
    final values = [for (final f in AudibilityProfile.bands) betterEarThresholdAt(f)].whereType<double>();
    return values.isEmpty ? null : values.reduce(math.min);
  }

  Contrast _pickContrast({Set<Contrast>? only}) {
    final options = [
      for (final c in Contrast.values)
        if (c.isHighFrequency && !inaudible.contains(c) && (only == null || only.contains(c))) c,
    ];
    final weights = [for (final c in options) weightOf(c)];
    final total = weights.reduce((a, b) => a + b);
    var r = _random.nextDouble() * total;
    for (var i = 0; i < options.length; i++) {
      r -= weights[i];
      if (r <= 0) return options[i];
    }
    return options.last;
  }
}
