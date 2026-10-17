import '../models/audiogram.dart';

/// Leitura do resultado do teste para o paciente: categoria aproximada e próximo passo.
///
/// O teste do app é uma **estimativa relativa** (fone não calibrado). A categoria usa os graus da
/// OMS (World Report on Hearing, 2021) sobre a média de 0,5/1/2/4 kHz só como orientação, sempre
/// acompanhada do aviso de que não é diagnóstico.
class HearingSummary {
  final EarSide ear;

  /// Média de 500, 1000, 2000 e 4000 Hz (null sem dados).
  final double? pta4;

  /// Média de 4, 6 e 8 kHz: onde ficam as pistas do /s/ e do /f/.
  final double? highFrequencyAverage;
  final bool anyNoResponse;
  final bool reliable;

  const HearingSummary({
    required this.ear,
    required this.pta4,
    required this.highFrequencyAverage,
    required this.anyNoResponse,
    required this.reliable,
  });

  factory HearingSummary.of(Audiogram audiogram, EarSide ear) {
    final points = ear == EarSide.left ? audiogram.leftEar : audiogram.rightEar;
    double? average(List<int> freqs) {
      final values = [
        for (final p in points)
          if (freqs.contains(p.frequency)) p.threshold,
      ];
      return values.length == freqs.length ? values.reduce((a, b) => a + b) / values.length : null;
    }

    return HearingSummary(
      ear: ear,
      pta4: average(const [500, 1000, 2000, 4000]),
      highFrequencyAverage: average(const [4000, 6000, 8000]),
      anyNoResponse: points.any((p) => p.noResponse),
      reliable: points.isNotEmpty && points.every((p) => p.reliable),
    );
  }

  /// Graus da OMS (2021) pela média de 4 frequências.
  String get category {
    final p = pta4;
    if (p == null) return 'Sem dados suficientes';
    if (p < 20) return 'Dentro do esperado';
    if (p < 35) return 'Perda leve';
    if (p < 50) return 'Perda moderada';
    if (p < 65) return 'Perda moderadamente severa';
    if (p < 80) return 'Perda severa';
    return 'Perda profunda';
  }

  /// Perda nos agudos bem maior que na média: o perfil que o treino mira.
  bool get highFrequencyLoss {
    final p = pta4, h = highFrequencyAverage;
    return p != null && h != null && h - p >= 15;
  }
}

/// O que o paciente deve fazer depois do teste.
enum NextStep { retest, seeProfessional, startTraining }

class HearingTestAdvice {
  /// Diferença entre orelhas que pede avaliação profissional (assimetria).
  static const double asymmetryDb = 15;

  final HearingSummary left;
  final HearingSummary right;

  HearingTestAdvice(Audiogram audiogram)
      : left = HearingSummary.of(audiogram, EarSide.left),
        right = HearingSummary.of(audiogram, EarSide.right);

  bool get asymmetric {
    final l = left.pta4, r = right.pta4;
    return l != null && r != null && (l - r).abs() >= asymmetryDb;
  }

  NextStep get nextStep {
    if (!left.reliable || !right.reliable) return NextStep.retest;
    final worst = [left.pta4, right.pta4].whereType<double>().fold<double>(0, (a, b) => a > b ? a : b);
    if (asymmetric || worst >= 35 || left.anyNoResponse || right.anyNoResponse) {
      return NextStep.seeProfessional;
    }
    return NextStep.startTraining;
  }

  String get message {
    switch (nextStep) {
      case NextStep.retest:
        return 'Algumas respostas ficaram inconsistentes. Refaça o teste num lugar silencioso, '
            'respondendo "Ouvi" só quando ouvir o som.';
      case NextStep.seeProfessional:
        final reason = asymmetric
            ? 'Um ouvido parece ouvir bem menos que o outro.'
            : 'O teste sugere uma perda que merece avaliação.';
        return '$reason Procure um fonoaudiólogo ou otorrinolaringologista para uma audiometria. '
            'Você pode treinar enquanto isso.';
      case NextStep.startTraining:
        return 'Você já pode começar o treino. Repita o teste de tempos em tempos.';
    }
  }
}
