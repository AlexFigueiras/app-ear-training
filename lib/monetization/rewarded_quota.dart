import 'dart:math' as math;

/// Quantas sessões PRO a pessoa já liberou hoje com vídeo premiado [MONETIZAÇÃO].
///
/// Fica só no aparelho: é um convite a experimentar o PRO, não um direito a proteger no
/// servidor. O dia é o do relógio local (vira à meia-noite da pessoa).
class RewardedQuota {
  /// Dia no formato aaaa-mm-dd.
  final String day;
  final int used;

  const RewardedQuota({required this.day, required this.used});

  static const RewardedQuota empty = RewardedQuota(day: '', used: 0);

  static String dayOf(DateTime now) {
    final local = now.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  int usedOn(DateTime now) => day == dayOf(now) ? used : 0;

  int remaining(DateTime now, int perDay) => math.max(0, perDay - usedOn(now));

  RewardedQuota register(DateTime now) =>
      RewardedQuota(day: dayOf(now), used: usedOn(now) + 1);

  Map<String, Object> toJson() => {'day': day, 'used': used};

  /// JSON salvo antes; qualquer coisa estranha vira [empty] (nunca bloqueia o app).
  factory RewardedQuota.fromJson(Object? json) {
    if (json is! Map) return empty;
    final day = json['day'];
    final used = json['used'];
    if (day is! String || used is! int || used < 0) return empty;
    return RewardedQuota(day: day, used: used);
  }
}
