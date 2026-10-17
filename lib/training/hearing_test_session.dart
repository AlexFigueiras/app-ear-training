import 'dart:math' as math;

import '../models/audiogram.dart';
import 'threshold_procedure.dart';

/// Um passo do teste: uma frequência numa orelha.
class HearingTestStep {
  final EarSide ear;
  final int frequency;

  /// Segunda medida de 1 kHz (confere a consistência das respostas).
  final bool isRetest;

  const HearingTestStep(this.ear, this.frequency, {this.isRetest = false});
}

/// Sequência completa do teste auditivo: uma orelha de cada vez, na ordem clínica
/// 1k → 2k → 3k → 4k → 6k → 8k → 1k (reteste) → 500 → 250.
/// Inclui 3 e 6 kHz, que o teste antigo não media e que importam para o /s/ e o /f/.
class HearingTestSession {
  static const List<int> order = [1000, 2000, 3000, 4000, 6000, 8000, 1000, 500, 250];
  static const int protocolVersion = AudiometryPoint.currentProtocol;

  /// Diferença máxima aceita entre as duas medidas de 1 kHz.
  static const double retestToleranceDb = 10;

  final ThresholdProcedure Function() _newProcedure;
  final List<HearingTestStep> steps;
  final Map<EarSide, Map<int, FrequencyResult>> _results = {EarSide.left: {}, EarSide.right: {}};
  final Map<EarSide, FrequencyResult> _retests = {};

  int _index = 0;
  late ThresholdProcedure _procedure;

  HearingTestSession({ThresholdProcedure Function()? procedureFactory, math.Random? random})
      : _newProcedure = procedureFactory ?? (() => ThresholdProcedure(random: random)),
        steps = [
          for (final ear in [EarSide.left, EarSide.right])
            for (var i = 0; i < order.length; i++)
              HearingTestStep(ear, order[i], isRetest: order[i] == 1000 && i > 0),
        ] {
    _procedure = _newProcedure();
  }

  bool get isDone => _index >= steps.length;
  HearingTestStep get currentStep => steps[_index];
  int get stepIndex => _index;
  double get progress => _index / steps.length;
  ThresholdProcedure get procedure => _procedure;

  /// true quando o próximo passo começa uma orelha nova (a tela avisa antes de seguir).
  bool get atEarStart => !isDone && (_index == 0 || steps[_index - 1].ear != currentStep.ear);

  Presentation next() => _procedure.next();

  /// Registra a resposta; quando a frequência termina, avança para o próximo passo.
  void respond(bool heard) {
    _procedure.respond(heard);
    if (!_procedure.isDone) return;
    final step = currentStep;
    final result = _procedure.result!;
    if (step.isRetest) {
      _retests[step.ear] = result;
    } else {
      _results[step.ear]![step.frequency] = result;
    }
    _index++;
    if (!isDone) _procedure = _newProcedure();
  }

  /// As duas medidas de 1 kHz diferem mais que [retestToleranceDb]: respostas inconsistentes.
  bool retestInconsistent(EarSide ear) {
    final first = _results[ear]![1000];
    final second = _retests[ear];
    if (first == null || second == null) return false;
    return (first.threshold - second.threshold).abs() > retestToleranceDb;
  }

  /// Pontos do audiograma de uma orelha, em ordem crescente de frequência.
  /// 1 kHz usa a melhor (menor) das duas medidas, como na audiometria clínica.
  List<AudiometryPoint> pointsFor(EarSide ear) {
    final byFrequency = Map<int, FrequencyResult>.of(_results[ear]!);
    final retest = _retests[ear];
    final first = byFrequency[1000];
    if (first != null && retest != null && retest.threshold < first.threshold) {
      byFrequency[1000] = retest;
    }
    final inconsistent = retestInconsistent(ear);
    final frequencies = byFrequency.keys.toList()..sort();
    return [
      for (final f in frequencies)
        AudiometryPoint(
          frequency: f,
          threshold: byFrequency[f]!.threshold,
          noResponse: byFrequency[f]!.noResponse,
          reliable: byFrequency[f]!.reliable && !inconsistent,
          protocol: protocolVersion,
        ),
    ];
  }
}
