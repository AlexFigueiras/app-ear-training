import 'dart:math' as math;

/// Escada adaptativa 3-acertos/1-erro (Levitt, 1971): converge para ~79,4% de acerto — perto da
/// faixa de 70–85% associada a aprendizado e motivação ("regra dos 85%", Wilson et al., 2019).
/// A escada antiga do Coquetel (1-acima/1-abaixo, com 2 opções) convergia para 50% = chute.
///
/// [value] é o parâmetro de dificuldade em dB, e **menor = mais difícil** nos dois usos:
/// - Coquetel: SNR (fala menos ruído);
/// - Palavras parecidas: reforço extra nos agudos.
///
/// Passo grande ([startStepDb]) até [reversalsForSmallStep] reversões, depois pequeno
/// ([smallStepDb]). O limiar estimado é a média das últimas [reversalsForEstimate] reversões.
class AdaptiveStaircase {
  final double minValue;
  final double maxValue;
  final double startStepDb;
  final double smallStepDb;
  final int correctToHarder;
  final int reversalsForSmallStep;
  final int reversalsForEstimate;

  double _value;
  int _streak = 0;
  int? _lastDirection; // -1 = ficou mais difícil, +1 = mais fácil
  final List<double> _reversals = [];
  int _trials = 0;

  AdaptiveStaircase({
    required double start,
    required this.minValue,
    required this.maxValue,
    this.startStepDb = 4,
    this.smallStepDb = 2,
    this.correctToHarder = 3,
    this.reversalsForSmallStep = 2,
    this.reversalsForEstimate = 6,
  }) : _value = start.clamp(minValue, maxValue).toDouble();

  double get value => _value;
  int get trials => _trials;
  List<double> get reversals => List.unmodifiable(_reversals);
  double get _step => _reversals.length < reversalsForSmallStep ? startStepDb : smallStepDb;

  /// Limiar estimado (média das últimas reversões), ou null com reversões de menos.
  double? get threshold {
    if (_reversals.length < reversalsForSmallStep + 2) return null;
    final usable = _reversals.skip(reversalsForSmallStep).toList();
    final recent = usable.sublist(math.max(0, usable.length - reversalsForEstimate));
    return recent.reduce((a, b) => a + b) / recent.length;
  }

  void record({required bool correct}) {
    _trials++;
    if (correct) {
      _streak++;
      if (_streak < correctToHarder) return;
      _streak = 0;
      _move(-1);
    } else {
      _streak = 0;
      _move(1);
    }
  }

  void _move(int direction) {
    if (_lastDirection != null && direction != _lastDirection) _reversals.add(_value);
    _lastDirection = direction;
    _value = (_value + direction * _step).clamp(minValue, maxValue).toDouble();
  }

  /// Estado salvo entre sessões (jsonb em `profiles.gamification_data`).
  Map<String, dynamic> toJson() => {'value': _value, 'threshold': threshold, 'trials': _trials};

  /// Retoma de onde a pessoa parou, [warmUpDb] mais fácil (o começo de sessão costuma ser pior),
  /// ou começa em [start] na primeira vez.
  factory AdaptiveStaircase.resume(
    Map<String, dynamic>? saved, {
    required double start,
    required double minValue,
    required double maxValue,
    double warmUpDb = 4,
  }) {
    final last = (saved?['value'] as num?)?.toDouble();
    return AdaptiveStaircase(
      start: last == null ? start : last + warmUpDb,
      minValue: minValue,
      maxValue: maxValue,
    );
  }
}

/// Duração-alvo da sessão: o treino passa a ser medido em minutos, não em número de tentativas
/// (a dose eficaz na literatura é em horas acumuladas).
class SessionClock {
  final Duration target;
  final DateTime _start;
  final DateTime Function() _now;

  SessionClock({this.target = const Duration(minutes: 10), DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _start = (now ?? DateTime.now)();

  Duration get elapsed => _now().difference(_start);
  bool get isOver => elapsed >= target;
  double get progress => (elapsed.inMilliseconds / target.inMilliseconds).clamp(0.0, 1.0);
  int get minutesLeft => math.max(0, ((target - elapsed).inSeconds + 59) ~/ 60); // arredonda para cima
}
