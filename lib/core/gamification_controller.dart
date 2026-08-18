import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'phoneme_map.dart';

/// Controlador Central de Gamificação Clínica [ORQUESTRADOR]
/// Gerencia XP, Energia Neural e Nível de Acuidade de forma reativa.
class GamificationController extends ChangeNotifier {
  static final GamificationController _instance = GamificationController._internal();
  factory GamificationController() => _instance;

  GamificationController._internal();

  int _totalXP = 0;
  int _neuralEnergy = 5;
  int _currentStreak = 0;
  int _sessionsCompletedToday = 0;
  String _acuityLevel = "INITIAL";

  // NÍVEL 4: Ambiente Hostil [EFEITO COQUETEL]
  double _currentSNR = 20.0;
  double _maxNoiseThreshold = 0.0;

  // Getters
  int get totalXP => _totalXP;
  int get neuralEnergy => _neuralEnergy;
  int get currentStreak => _currentStreak;
  int get sessionsCompletedToday => _sessionsCompletedToday;
  String get acuityLevel => _acuityLevel;
  bool get hasEnergy => _neuralEnergy > 0;
  // Recomendação suave (sem bloco duro): ≥2 sessões/dia = mínimo efetivo
  bool get recommendRest => _sessionsCompletedToday >= 2;
  /// Tempo restante de recuperação em caso de esgotamento de energia neural
  Duration get remainingRestTime {
    if (_neuralEnergy > 0) return Duration.zero;
    // Protocolo de recuperação de fadiga neural: janela de 4h
    final now = DateTime.now();
    final nextAvailable = DateTime(now.year, now.month, now.day, now.hour + 4);
    final diff = nextAvailable.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }
  double get currentSNR => _currentSNR;
  double get maxNoiseThreshold => _maxNoiseThreshold;

  /// Seleção Inteligente baseada no Audiograma [Fase 1]
  Map<String, dynamic>? getSmartPhoneme(List<dynamic> audiogramData) {
    final List<Map<String, dynamic>> level2Stimuli = List<Map<String, dynamic>>.from(PHONEME_REHAB_DATA['level_2']);
    
    // Filtra frequências com perda > 25dB
    final criticalFreqs = audiogramData.where((p) => (p['threshold'] as num) > 25).map((p) => p['frequency'] as int).toList();
    
    if (criticalFreqs.isEmpty) return level2Stimuli[math.Random().nextInt(level2Stimuli.length)];

    // Filtra fonemas na faixa de +/- 1500Hz das frequências críticas
    final smartMatch = level2Stimuli.where((s) {
      final band = s['freq_band'] as int;
      return criticalFreqs.any((f) => (band - f).abs() <= 1500);
    }).toList();

    if (smartMatch.isEmpty) return level2Stimuli[math.Random().nextInt(level2Stimuli.length)];
    return smartMatch[math.Random().nextInt(smartMatch.length)];
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

  void consumeEnergy() {
    if (_neuralEnergy > 0) {
      _neuralEnergy--;
      notifyListeners();
    }
  }

  /// Reinicia energia para nova sessão. Chamar no initState de cada tela de treino.
  void resetEnergyForNewSession() {
    _neuralEnergy = 5;
    notifyListeners();
  }

  void resetEnergy() {
    _neuralEnergy = 5;
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
      'neural_energy': _neuralEnergy,
      'current_streak': _currentStreak,
      'acuity_level': _acuityLevel,
      'max_noise_threshold': _maxNoiseThreshold,
      'last_training_at': DateTime.now().toIso8601String(),
    };
  }

  void fromMap(Map<String, dynamic> map) {
    _totalXP = (map['total_xp'] as num?)?.toInt() ?? 0;
    _neuralEnergy = (map['neural_energy'] as num?)?.toInt() ?? 5;
    _currentStreak = (map['current_streak'] as num?)?.toInt() ?? 0;
    _acuityLevel = map['acuity_level'] as String? ?? "INITIAL";
    _maxNoiseThreshold = (map['max_noise_threshold'] as num?)?.toDouble() ?? 0.0;
    notifyListeners();
  }
}
