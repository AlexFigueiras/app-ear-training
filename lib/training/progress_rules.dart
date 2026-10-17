import 'dart:math' as math;

import '../models/rehab_session.dart';

/// Os três treinos (id usado em `training_state`).
enum TrainingId {
  phonemic('phonemic', 'Palavras parecidas', RehabLevel.phonemicDiscrimination, 7),
  cocktail('cocktail', 'Conversa no barulho', RehabLevel.speechInNoise, 10),
  spatial('spatial', 'Voz de um lado, barulho do outro', RehabLevel.spatialAttention, 10);

  final String module;
  final String title;
  final RehabLevel level;
  final int maxLevel;

  const TrainingId(this.module, this.title, this.level, this.maxLevel);

  static TrainingId? ofLevel(RehabLevel level) {
    for (final t in values) {
      if (t.level == level) return t;
    }
    return null;
  }
}

/// Recompensa de uma sessão (mostrada no resumo).
class SessionReward {
  final int points;
  final bool newBest;
  final bool goalJustReached;

  const SessionReward({required this.points, required this.newBest, required this.goalJustReached});
}

/// Regras da gamificação nova (Etapa 10 do plano), em Dart puro.
///
/// Princípios:
/// - **Pontos por esforço**, iguais em todos os treinos (antes o XP dobrava nos treinos fáceis e
///   era menor no Coquetel), mais bônus por recorde pessoal e pela meta do dia.
/// - **Nível vem do desempenho**, o limiar da escada adaptativa, nunca do XP acumulado. O antigo
///   "STATUS: INITIAL/ADVANCED" era só tempo de uso.
/// - **Meta diária em minutos** (a dose eficaz é medida em horas acumuladas) e 5 dias por semana.
///   A sequência conta dias com a meta cumprida e é recalculada do histórico a cada abertura
///   (antes subia a cada vez que a Home abria).
class ProgressRules {
  const ProgressRules._();

  static const int dailyGoalMinutes = 15;
  static const int weeklyGoalDays = 5;
  static const int pointsPerMinute = 10;
  static const int bestBonus = 50;
  static const int goalBonus = 30;

  /// Nível a partir do qual o treino seguinte é recomendado ("domínio").
  static const int masteryLevel = 5;

  // --- Níveis em linguagem comum ---

  /// Palavras parecidas: reforço agudo 24 dB = nível 1 ... 0 dB = nível 7.
  static int phonemicLevel(double boostDb) => (1 + ((24 - boostDb) / 4).round()).clamp(1, 7);

  /// Treinos com ruído: SNR +15 dB = nível 1 ... -10 dB = nível 10.
  static int noiseLevel(double snrDb) => (1 + ((15 - snrDb) / 25 * 9).round()).clamp(1, 10);

  static int levelOf(TrainingId t, double value) =>
      t == TrainingId.phonemic ? phonemicLevel(value) : noiseLevel(value);

  /// Nível atual de um treino pelo estado salvo da escada (limiar, ou o valor atual).
  static int? currentLevel(TrainingId t, Map<String, dynamic>? state) {
    final value = (state?['threshold'] as num?) ?? (state?['value'] as num?);
    return value == null ? null : levelOf(t, value.toDouble());
  }

  /// Nível alcançado numa sessão salva (histórico).
  static int? sessionLevel(RehabSession s) {
    final t = TrainingId.ofLevel(s.level);
    if (t == null) return null;
    final m = s.metadata ?? const {};
    final value = t == TrainingId.phonemic
        ? (m['boost_threshold_db'] ?? m['final_boost_db'])
        : (m['snr_threshold'] ?? m['final_snr']);
    return value is num ? levelOf(t, value.toDouble()) : null;
  }

  static String stageName(int level, int maxLevel) {
    final f = level / maxLevel;
    if (f <= 1 / 3) return 'Começando';
    if (f <= 2 / 3) return 'Avançando';
    return 'Dominando';
  }

  // --- Recorde e pontos ---

  /// Limiar menor = melhor (menos reforço ou mais ruído). Primeira medida conta como recorde.
  static bool isNewBest(double? previousBest, double? threshold) =>
      threshold != null && (previousBest == null || threshold < previousBest);

  static int sessionPoints({required Duration duration, required bool newBest, required bool goalJustReached}) =>
      (duration.inSeconds / 60 * pointsPerMinute).round() + (newBest ? bestBonus : 0) + (goalJustReached ? goalBonus : 0);

  // --- Minutos, meta e sequência (sempre do histórico) ---

  static Duration durationOf(RehabSession s) {
    final ms = s.metadata?['duration_ms'];
    if (ms is num) return Duration(milliseconds: ms.toInt());
    return Duration(milliseconds: (s.averageResponseTimeMs * s.totalTrials).round());
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static Map<DateTime, double> minutesByDay(List<RehabSession> history) {
    final map = <DateTime, double>{};
    for (final s in history) {
      final day = _day(s.date.toLocal());
      map[day] = (map[day] ?? 0) + durationOf(s).inSeconds / 60;
    }
    return map;
  }

  static double minutesOn(List<RehabSession> history, DateTime day) => minutesByDay(history)[_day(day)] ?? 0;

  /// Dias seguidos com a meta cumprida, terminando hoje (se já cumpriu) ou ontem.
  static int streakDays(List<RehabSession> history, DateTime now) {
    final byDay = minutesByDay(history);
    bool met(DateTime d) => (byDay[d] ?? 0) >= dailyGoalMinutes;
    var day = _day(now);
    if (!met(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (met(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Dias desta semana (segunda a domingo) com a meta cumprida.
  static int goalDaysThisWeek(List<RehabSession> history, DateTime now) {
    final byDay = minutesByDay(history);
    final monday = _day(now).subtract(Duration(days: now.weekday - 1));
    return [
      for (var i = 0; i < 7; i++) monday.add(Duration(days: i)),
    ].where((d) => (byDay[d] ?? 0) >= dailyGoalMinutes).length;
  }

  /// "1 dia", "2 dias" (achado E3: aparecia "1 dias").
  static String days(int n) => n == 1 ? '1 dia' : '$n dias';

  // --- Próximo passo ---

  /// Treino recomendado: Palavras parecidas até dominar ([masteryLevel]); depois, com o plano
  /// completo, Conversa no barulho e então Voz de um lado.
  static TrainingId recommend({required Map<TrainingId, int?> levels, required bool hasPro}) {
    if ((levels[TrainingId.phonemic] ?? 0) < masteryLevel || !hasPro) return TrainingId.phonemic;
    if ((levels[TrainingId.cocktail] ?? 0) < masteryLevel) return TrainingId.cocktail;
    return TrainingId.spatial;
  }

  /// Minutos que faltam para a meta de hoje.
  static int minutesLeftToday(double minutesToday) => math.max(0, (dailyGoalMinutes - minutesToday).ceil());
}
