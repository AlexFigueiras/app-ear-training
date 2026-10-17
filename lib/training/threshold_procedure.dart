import 'dart:math' as math;

/// Uma apresentação do teste: tom no nível [level] (dB relativos) ou tentativa silenciosa.
class Presentation {
  final double level;

  /// Tentativa silenciosa (sem tom). Responder "ouvi" aqui é falso alarme.
  final bool isCatch;

  const Presentation(this.level, {this.isCatch = false});
}

/// Resultado de uma frequência numa orelha.
class FrequencyResult {
  /// Limiar estimado (dB relativos). Com [noResponse], é o nível máximo testado.
  final double threshold;

  /// Não ouviu nem no volume máximo do aparelho.
  final bool noResponse;

  /// Falsos alarmes demais (respondeu "ouvi" em tentativas silenciosas): resultado duvidoso.
  final bool reliable;

  final int presentations;
  final int falseAlarms;

  const FrequencyResult({
    required this.threshold,
    required this.noResponse,
    required this.reliable,
    required this.presentations,
    required this.falseAlarms,
  });
}

/// Procedimento de limiar de uma frequência: Hughson-Westlake modificado (ASHA 2005).
///
/// - Começa em [startLevel]; se não ouvir, sobe de 20 em 20 até ouvir (familiarização).
/// - Depois: ouviu → desce 10 dB; não ouviu → sobe 5 dB.
/// - Limiar = menor nível com 2 respostas em apresentações **ascendentes** (vindas de "não ouvi").
/// - Sem resposta 2× no nível máximo → "sem resposta" (antes o teste subia até 120 e travava).
/// - Ouviu no nível mínimo → conta como resposta ascendente ali (antes ficava preso em -10).
/// - ~[catchProbability] das apresentações são silenciosas. 2 falsos alarmes reiniciam a
///   frequência ([restartedForFalseAlarms]); 4 no total encerram com resultado duvidoso.
/// - Teto de [maxPresentations]: encerra com a melhor estimativa disponível.
class ThresholdProcedure {
  final double minLevel;
  final double maxLevel;
  final double startLevel;
  final double catchProbability;
  final int maxPresentations;

  /// Tentativas silenciosas mínimas antes de aceitar um limiar.
  static const int minVerificationCatches = 2;
  final math.Random _random;

  ThresholdProcedure({
    this.minLevel = -10,
    this.maxLevel = 80,
    this.startLevel = 40,
    this.catchProbability = 0.2,
    this.maxPresentations = 30,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    _level = startLevel;
  }

  late double _level;
  bool _familiarizing = true;
  bool? _lastToneResponse; // resposta à última apresentação COM tom
  final Map<double, int> _ascendingYes = {};
  int _maxLevelMisses = 0;
  int _presentations = 0;
  int _falseAlarmsSinceRestart = 0;
  int _falseAlarmsTotal = 0;
  int _catchesSinceTone = 0;
  Presentation? _pending;
  int _catchesPresented = 0;

  // Limiar encontrado, aguardando as tentativas silenciosas de verificação.
  double? _candidate;
  bool _candidateNoResponse = false;
  FrequencyResult? _result;

  /// true logo depois de um reinício por falsos alarmes (a tela mostra a orientação).
  bool restartedForFalseAlarms = false;

  bool get isDone => _result != null;
  FrequencyResult? get result => _result;

  /// Próxima apresentação. Chame [respond] antes de pedir outra.
  Presentation next() {
    assert(!isDone, 'Procedimento já terminou');
    assert(_pending == null, 'Responda à apresentação anterior antes');
    // Nenhuma silenciosa na familiarização; fora da verificação final, nunca duas seguidas.
    final silent = _candidate != null ||
        !_familiarizing &&
        _catchesSinceTone == 0 &&
        _random.nextDouble() < catchProbability;
    _pending = silent ? Presentation(_level, isCatch: true) : Presentation(_level);
    return _pending!;
  }

  void respond(bool heard) {
    final p = _pending;
    assert(p != null, 'Nenhuma apresentação pendente');
    _pending = null;
    _presentations++;
    restartedForFalseAlarms = false;

    if (p!.isCatch) {
      _catchesSinceTone++;
      _catchesPresented++;
      if (heard) _registerFalseAlarm();
      final candidate = _candidate;
      if (!isDone && candidate != null && _catchesPresented >= minVerificationCatches) {
        _finish(candidate, noResponse: _candidateNoResponse);
        return;
      }
      _checkPresentationCap();
      return;
    }
    _catchesSinceTone = 0;

    if (_familiarizing) {
      if (heard) {
        _familiarizing = false;
        _lastToneResponse = true;
        _level = math.max(minLevel, _level - 10);
      } else if (_level >= maxLevel) {
        _registerMaxLevelMiss();
      } else {
        _level = math.min(maxLevel, _level + 20);
      }
      _checkPresentationCap();
      return;
    }

    final ascending = _lastToneResponse == false || _level <= minLevel;
    if (heard) {
      if (ascending) {
        final count = (_ascendingYes[_level] ?? 0) + 1;
        _ascendingYes[_level] = count;
        if (count >= 2) {
          _verifyThenFinish(_level, noResponse: false);
          return;
        }
      }
      _level = math.max(minLevel, _level - 10);
    } else {
      if (_level >= maxLevel) {
        _registerMaxLevelMiss();
        if (isDone) return;
      }
      _level = math.min(maxLevel, _level + 5);
    }
    _lastToneResponse = heard;
    _checkPresentationCap();
  }

  void _registerMaxLevelMiss() {
    _maxLevelMisses++;
    if (_maxLevelMisses >= 2) _verifyThenFinish(maxLevel, noResponse: true);
  }

  void _registerFalseAlarm() {
    _falseAlarmsSinceRestart++;
    _falseAlarmsTotal++;
    if (_falseAlarmsTotal >= 4) {
      _finishWithBestEstimate(reliable: false);
    } else if (_falseAlarmsSinceRestart >= 2) {
      _restart();
    }
  }

  /// Antes de aceitar o limiar, garante [minVerificationCatches] tentativas silenciosas nesta
  /// tentativa: quem responde "ouvi" para tudo desce até o piso com poucas apresentações e, sem
  /// isso, passava como confiável.
  void _verifyThenFinish(double threshold, {required bool noResponse}) {
    if (_catchesPresented >= minVerificationCatches) {
      _finish(threshold, noResponse: noResponse);
    } else {
      _candidate = threshold;
      _candidateNoResponse = noResponse;
    }
  }

  void _restart() {
    _candidate = null;
    _catchesPresented = 0;
    _level = startLevel;
    _familiarizing = true;
    _lastToneResponse = null;
    _ascendingYes.clear();
    _maxLevelMisses = 0;
    _falseAlarmsSinceRestart = 0;
    restartedForFalseAlarms = true;
  }

  void _checkPresentationCap() {
    if (!isDone && _presentations >= maxPresentations) _finishWithBestEstimate(reliable: true);
  }

  /// Sem o critério de 2 ascendentes: usa o menor nível com 1 resposta ascendente, ou o nível atual.
  void _finishWithBestEstimate({required bool reliable}) {
    final heardLevels = _ascendingYes.keys.toList()..sort();
    _finish(heardLevels.isNotEmpty ? heardLevels.first : _level,
        noResponse: false, reliable: reliable);
  }

  void _finish(double threshold, {required bool noResponse, bool reliable = true}) {
    _result = FrequencyResult(
      threshold: threshold,
      noResponse: noResponse,
      reliable: reliable && _falseAlarmsTotal < 4,
      presentations: _presentations,
      falseAlarms: _falseAlarmsTotal,
    );
  }
}
