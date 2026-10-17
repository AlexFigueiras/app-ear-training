import 'dart:math' as math;

import '../models/rehab_session.dart';

/// Um trio de dígitos apresentado num SNR.
class DigitTriplet {
  final List<int> digits;
  final double snrDb;

  const DigitTriplet(this.digits, this.snrDb);
}

/// Teste de dígitos no ruído (DIN; Smits et al., 2004), a medida de progresso do app.
///
/// Por que existe: o treino melhora a própria tarefa treinada, e parte dessa "melhora" é só
/// familiaridade (Amitay et al., 2006). A medida honesta usa material que o treino NÃO usa
/// (números, voz própria, ruído de fala) e é repetida de tempos em tempos.
///
/// Procedimento: 24 trios; acerto = os 3 dígitos certos; 1-acima/1-abaixo em passos de 2 dB a
/// partir de 0 dB (com 3 dígitos o chute é 1/1000, então converge para 50% de trios certos).
/// SRT = média dos SNRs dos trios 5 a 24 e do 25º (o que viria a seguir).
///
/// É uma **medida interna, não validada clinicamente**: o DIN validado usa gravações
/// homogeneizadas e calibradas; aqui os dígitos vêm do TTS, normalizados só por RMS.
class DinProcedure {
  static const int totalTriplets = 24;
  static const double startSnr = 0;
  static const double stepDb = 2;
  static const double minSnr = -20;
  static const double maxSnr = 10;

  /// Intervalo entre medidas.
  static const Duration interval = Duration(days: 14);

  final math.Random _random;
  double _snr = startSnr;
  final List<double> _presented = [];
  int _correctTriplets = 0;
  List<int>? _last;

  DinProcedure({math.Random? random}) : _random = random ?? math.Random();

  bool get isDone => _presented.length >= totalTriplets;
  int get index => _presented.length;
  int get correctTriplets => _correctTriplets;
  double get currentSnr => _snr;
  List<double> get presentedSnrs => List.unmodifiable(_presented);

  /// Próximo trio: 3 dígitos distintos de 0 a 9, nunca igual ao anterior.
  DigitTriplet next() {
    List<int> digits;
    do {
      digits = ([for (var d = 0; d <= 9; d++) d]..shuffle(_random)).take(3).toList();
    } while (_last != null && _sameDigits(digits, _last!));
    _last = digits;
    return DigitTriplet(digits, _snr);
  }

  /// [answer] = os 3 dígitos digitados, na ordem. Devolve se o trio estava todo certo.
  bool respond(List<int> answer) {
    final target = _last;
    assert(target != null && !isDone);
    final correct = _sameDigits(answer, target!);
    _presented.add(_snr);
    if (correct) _correctTriplets++;
    _snr = (_snr + (correct ? -stepDb : stepDb)).clamp(minSnr, maxSnr).toDouble();
    return correct;
  }

  /// Limiar de recepção de fala no ruído (dB): SNR com 50% dos trios certos. Menor = melhor.
  double? get srt {
    if (!isDone) return null;
    final values = [..._presented.skip(4), _snr];
    return values.reduce((a, b) => a + b) / values.length;
  }

  static bool _sameDigits(List<int> a, List<int> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  /// Hora de medir de novo? (nunca mediu, ou a última medida tem [interval] ou mais).
  static bool isDue(List<RehabSession> history, {DateTime? now}) {
    final measures = history.where((s) => s.level == RehabLevel.digitsInNoise).toList();
    if (measures.isEmpty) return true;
    final last = measures.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);
    return (now ?? DateTime.now()).difference(last) >= interval;
  }

  /// SRT em linguagem comum.
  static String describe(double srt) {
    final db = srt.abs().toStringAsFixed(1).replaceAll('.', ',');
    if (srt.abs() < 0.5) return 'Você entendeu metade dos trios com o ruído tão alto quanto a voz.';
    return srt < 0
        ? 'Você entendeu metade dos trios mesmo com o ruído $db dB mais alto que a voz.'
        : 'Você entendeu metade dos trios com o ruído $db dB mais baixo que a voz.';
  }
}
