import 'package:flutter/foundation.dart';

/// Controlador Central de Gamificação Clínica [ORQUESTRADOR]
/// Gerencia XP, sequência de dias e SNR do Coquetel. A "Energia Neural" (vidas perdidas a cada
/// erro) saiu na Etapa 6 do plano: a escada adaptativa erra de propósito ~20–30% das vezes, e
/// punir esse erro gerava ansiedade sem efeito clínico. O limite de sessão passa a ser por tempo.
/// Dados antigos com `neural_energy` são lidos e ignorados.
class GamificationController extends ChangeNotifier {
  static final GamificationController _instance = GamificationController._internal();
  factory GamificationController() => _instance;

  GamificationController._internal();

  int _totalXP = 0;
  int _currentStreak = 0;
  int _sessionsCompletedToday = 0;
  String _acuityLevel = "INITIAL";

  // NÍVEL 4: Ambiente Hostil [EFEITO COQUETEL]
  double _currentSNR = 20.0;
  double _maxNoiseThreshold = 0.0;

  // Estado das escadas adaptativas por treino (ex.: "phonemic", "cocktail"), salvo entre sessões
  // para a próxima começar de onde a pessoa parou (Etapa 7).
  final Map<String, Map<String, dynamic>> _trainingState = {};

  // Getters
  int get totalXP => _totalXP;
  int get currentStreak => _currentStreak;
  int get sessionsCompletedToday => _sessionsCompletedToday;
  String get acuityLevel => _acuityLevel;
  // Recomendação suave (sem bloco duro): ≥2 sessões/dia = mínimo efetivo
  bool get recommendRest => _sessionsCompletedToday >= 2;
  double get currentSNR => _currentSNR;
  double get maxNoiseThreshold => _maxNoiseThreshold;

  Map<String, dynamic>? trainingState(String module) => _trainingState[module];

  void saveTrainingState(String module, Map<String, dynamic> state) {
    _trainingState[module] = state;
    notifyListeners();
  }

  /// Adiciona XP baseado na performance e tipo de fonema [ANALYTICS]
  void addAcuityXP(double successRate, List<String> phonemes) {
    double baseXP = 100 * successRate;
    bool hasHighFrequencyPhonemes = phonemes.any((p) =>
      ['s', 'f', 't', 'ç', 'x', 'ch', 'spatial', 'z', 'fricative', 'sibilant'].contains(p.toLowerCase())
    );

    double multiplier = hasHighFrequencyPhonemes ? 2.0 : 1.0;
    _totalXP += (baseXP * multiplier).toInt();

    // Nível 4: acerto sustentado acima de 80% → aumenta dificuldade (SNR menor)
    if (successRate >= 0.8 && phonemes.contains('cocktail')) {
      _currentSNR = (_currentSNR - 2.0).clamp(-10.0, 20.0);
      if (_currentSNR < _maxNoiseThreshold) _maxNoiseThreshold = _currentSNR;
    }

    _updateAcuityLevel();
    notifyListeners();
  }

  void resetSNR() {
    _currentSNR = 20.0;
    notifyListeners();
  }

  void incrementSessionsToday() {
    _sessionsCompletedToday++;
    notifyListeners();
  }

  void setSessionsCompletedToday(int count) {
    _sessionsCompletedToday = count;
    notifyListeners();
  }

  void updateStreak(int days) {
    _currentStreak = days;
    notifyListeners();
  }

  /// Zera o estado em memória (logout / exclusão de conta): o próximo usuário do aparelho
  /// não pode herdar XP, sequência ou SNR do anterior.
  void resetForNewUser() {
    _totalXP = 0;
    _currentStreak = 0;
    _sessionsCompletedToday = 0;
    _acuityLevel = "INITIAL";
    _currentSNR = 20.0;
    _maxNoiseThreshold = 0.0;
    _trainingState.clear();
    notifyListeners();
  }

  void _updateAcuityLevel() {
    if (_totalXP > 5000) {
      _acuityLevel = "ADVANCED";
    } else if (_totalXP > 1000) {
      _acuityLevel = "MODERATE";
    } else {
      _acuityLevel = "INITIAL";
    }
  }

  /// Sincronização com Supabase [PERSISTÊNCIA]
  Map<String, dynamic> toMapForSupabase() {
    return {
      'total_xp': _totalXP,
      'current_streak': _currentStreak,
      'acuity_level': _acuityLevel,
      'max_noise_threshold': _maxNoiseThreshold,
      // Cópia: quem recebe o mapa não pode ser afetado por um reset posterior.
      'training_state': {for (final e in _trainingState.entries) e.key: Map<String, dynamic>.of(e.value)},
      'last_training_at': DateTime.now().toIso8601String(),
    };
  }

  void fromMap(Map<String, dynamic> map) {
    _totalXP = (map['total_xp'] as num?)?.toInt() ?? 0;
    _currentStreak = (map['current_streak'] as num?)?.toInt() ?? 0;
    _acuityLevel = map['acuity_level'] as String? ?? "INITIAL";
    _maxNoiseThreshold = (map['max_noise_threshold'] as num?)?.toDouble() ?? 0.0;
    _trainingState
      ..clear()
      ..addAll({
        for (final e in ((map['training_state'] as Map?) ?? const {}).entries)
          if (e.value is Map) e.key as String: Map<String, dynamic>.from(e.value as Map),
      });
    notifyListeners();
  }
}
