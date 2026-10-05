import 'package:flutter/foundation.dart';

import '../training/progress_rules.dart';

/// Estado da gamificação (Etapa 10 do plano). As regras ficam em `ProgressRules` (Dart puro).
///
/// - **Pontos de treino:** por esforço, iguais em todos os treinos, com bônus por recorde e pela
///   meta do dia. Ficam salvos em `total_xp` (nome antigo, mantido para não perder o histórico).
/// - **Nível:** por treino, do limiar da escada adaptativa (`training_state`), nunca do XP.
/// - **Minutos de hoje, dias seguidos e dias da semana:** calculados do histórico de sessões pela
///   Home ([setDailyProgress]), não incrementados aqui. A sequência antiga subia a cada abertura
///   da Home.
///
/// Saíram: "Energia Neural" (Etapa 6), "nível de acuidade" por XP, SNR do Coquetel aqui dentro e
/// contagem de sessões por dia. Dados antigos com essas chaves são lidos e ignorados.
class GamificationController extends ChangeNotifier {
  static final GamificationController _instance = GamificationController._internal();
  factory GamificationController() => _instance;

  GamificationController._internal();

  int _points = 0;
  double _minutesToday = 0;
  int _streakDays = 0;
  int _goalDaysThisWeek = 0;

  // Estado das escadas por treino ("phonemic", "cocktail", "spatial"): valor, limiar e recorde.
  final Map<String, Map<String, dynamic>> _trainingState = {};

  int get trainingPoints => _points;
  double get minutesToday => _minutesToday;
  int get streakDays => _streakDays;
  int get goalDaysThisWeek => _goalDaysThisWeek;
  bool get dailyGoalMet => _minutesToday >= ProgressRules.dailyGoalMinutes;

  Map<String, dynamic>? trainingState(String module) => _trainingState[module];

  void saveTrainingState(String module, Map<String, dynamic> state) {
    _trainingState[module] = {..._trainingState[module] ?? const {}, ...state};
    notifyListeners();
  }

  int? levelOf(TrainingId t) => ProgressRules.currentLevel(t, _trainingState[t.module]);

  /// Progresso do dia, calculado do histórico pela Home.
  void setDailyProgress({required double minutesToday, required int streakDays, required int goalDaysThisWeek}) {
    _minutesToday = minutesToday;
    _streakDays = streakDays;
    _goalDaysThisWeek = goalDaysThisWeek;
    notifyListeners();
  }

  /// Fecha uma sessão: soma minutos de hoje, verifica recorde ([threshold], menor = melhor) e
  /// soma os pontos. [module] null = medida (dígitos no ruído), sem recorde de treino.
  SessionReward completeSession({String? module, double? threshold, required Duration duration}) {
    final before = _minutesToday;
    _minutesToday += duration.inSeconds / 60;
    final goalJustReached =
        before < ProgressRules.dailyGoalMinutes && _minutesToday >= ProgressRules.dailyGoalMinutes;

    var newBest = false;
    if (module != null) {
      final best = (_trainingState[module]?['best'] as num?)?.toDouble();
      newBest = ProgressRules.isNewBest(best, threshold);
      if (newBest) _trainingState[module] = {..._trainingState[module] ?? const {}, 'best': threshold};
    }

    final reward = SessionReward(
      points: ProgressRules.sessionPoints(duration: duration, newBest: newBest, goalJustReached: goalJustReached),
      newBest: newBest,
      goalJustReached: goalJustReached,
    );
    _points += reward.points;
    notifyListeners();
    return reward;
  }

  /// Zera o estado em memória (logout / exclusão de conta): o próximo usuário do aparelho
  /// não pode herdar pontos, níveis ou recordes do anterior.
  void resetForNewUser() {
    _points = 0;
    _minutesToday = 0;
    _streakDays = 0;
    _goalDaysThisWeek = 0;
    _trainingState.clear();
    notifyListeners();
  }

  /// Sincronização com Supabase (`profiles.gamification_data`).
  Map<String, dynamic> toMapForSupabase() => {
        'total_xp': _points,
        // Cópia: quem recebe o mapa não pode ser afetado por um reset posterior.
        'training_state': {for (final e in _trainingState.entries) e.key: Map<String, dynamic>.of(e.value)},
        'last_training_at': DateTime.now().toIso8601String(),
      };

  void fromMap(Map<String, dynamic> map) {
    _points = (map['total_xp'] as num?)?.toInt() ?? 0;
    _trainingState
      ..clear()
      ..addAll({
        for (final e in ((map['training_state'] as Map?) ?? const {}).entries)
          if (e.value is Map) e.key as String: Map<String, dynamic>.from(e.value as Map),
      });
    notifyListeners();
  }
}
