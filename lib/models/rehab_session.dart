
enum RehabLevel {
  toneIsolation(1, unlockThreshold: 90.0),
  phonemicDiscrimination(2, unlockThreshold: 85.0),
  spatialAttention(3, unlockThreshold: 80.0),
  speechInNoise(4, unlockThreshold: 0.0),

  /// Medida de progresso (teste de dígitos no ruído, Etapa 8): não é treino nem nível.
  digitsInNoise(5, unlockThreshold: 0.0);

  final int value;
  final double unlockThreshold; // Precisão necessária para liberar o próximo nível

  const RehabLevel(this.value, {this.unlockThreshold = 85.0});
}

class RehabSession {
  final String? id;
  final String patientId;
  final DateTime date;
  final RehabLevel level;
  final int totalTrials;
  final int correctAnswers;
  final double averageResponseTimeMs;
  final Map<String, dynamic>? metadata; // Para armazenar fonemas testados, SNR, etc.

  RehabSession({
    this.id,
    required this.patientId,
    required this.date,
    required this.level,
    required this.totalTrials,
    required this.correctAnswers,
    required this.averageResponseTimeMs,
    this.metadata,
  });

  double get accuracy => totalTrials > 0 ? (correctAnswers / totalTrials) * 100 : 0;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'date': date.toIso8601String(),
    'level': level.value,
    'total_trials': totalTrials,
    'correct_answers': correctAnswers,
    'avg_response_time_ms': averageResponseTimeMs,
    'metadata': metadata,
    'accuracy': accuracy,
  };

  factory RehabSession.fromJson(Map<String, dynamic> json) => RehabSession(
    id: json['id'],
    patientId: json['patient_id'],
    date: DateTime.parse(json['date'] ?? json['created_at']),
    level: RehabLevel.values.firstWhere((e) => e.value == json['level']),
    totalTrials: json['total_trials'],
    correctAnswers: json['correct_answers'],
    averageResponseTimeMs: (json['avg_response_time_ms'] as num).toDouble(),
    metadata: json['metadata'],
  );

  /// Determina se o nível atual desbloqueou o próximo baseado no histórico.
  static int calculateUnlockedLevel(List<RehabSession> history) {
    int maxUnlocked = 1; // Nível 1 sempre começa liberado
    
    for (var level in RehabLevel.values) {
      if (level == RehabLevel.speechInNoise) break;

      final sessionForLevel = history.where((s) => s.level == level).toList();
      if (sessionForLevel.isEmpty) break;

      // Se a última sessão (ou a melhor) atingiu o threshold, libera o próximo
      final bestAccuracy = sessionForLevel.map((s) => s.accuracy).reduce((a, b) => a > b ? a : b);
      
      if (bestAccuracy >= level.unlockThreshold) {
        maxUnlocked = level.value + 1;
      } else {
        break; // Bloqueado no nível atual
      }
    }
    return maxUnlocked;
  }
}
