
/// Representação das Orelhas
enum EarSide { left, right, both }

/// Representação da Via de Condução (Aérea ou Óssea)
enum ConductionType { air, bone }

/// Ponto do audiograma: frequência (Hz) e limiar em dB **relativos** (o fone não é calibrado,
/// então não é dB HL clínico; ver `lib/training/threshold_procedure.dart`).
class AudiometryPoint {
  /// Versão do protocolo do teste do app.
  /// 1 (ou ausente) = teste antigo, medido através do compressor: subestima a perda em agudos.
  /// 2 = Etapa 4: sem processamento, rampas, tentativas silenciosas, 3 e 6 kHz.
  static const int currentProtocol = 2;

  final int frequency;
  final double threshold;
  final ConductionType conduction;
  final bool masked;

  /// Não ouviu nem no volume máximo do aparelho ([threshold] = nível máximo testado).
  final bool noResponse;

  /// false = respostas inconsistentes (falsos alarmes, reteste de 1 kHz divergente).
  final bool reliable;

  final int protocol;

  AudiometryPoint({
    required this.frequency,
    required this.threshold,
    this.conduction = ConductionType.air,
    this.masked = false,
    this.noResponse = false,
    this.reliable = true,
    this.protocol = 1,
  });

  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'threshold': threshold,
    'conduction': conduction.name,
    'masked': masked,
    'no_response': noResponse,
    'reliable': reliable,
    'protocol': protocol,
  };

  factory AudiometryPoint.fromJson(Map<String, dynamic> json) => AudiometryPoint(
    frequency: json['frequency'],
    threshold: (json['threshold'] as num).toDouble(),
    conduction: ConductionType.values.byName(json['conduction'] ?? 'air'),
    masked: json['masked'] ?? false,
    noResponse: json['no_response'] ?? false,
    reliable: json['reliable'] ?? true,
    protocol: (json['protocol'] as num?)?.toInt() ?? 1,
  );

  /// Validação técnica clínica
  bool get isValid => (threshold >= -10 && threshold <= 120);
}

/// Modelo de Audiograma Completo focado em Reabilitação Auditiva.
class Audiogram {
  final String id;
  final String patientId;
  final DateTime date;
  List<AudiometryPoint> leftEar;
  List<AudiometryPoint> rightEar;
  final String? notes;

  Audiogram({
    required this.id,
    required this.patientId,
    required this.date,
    required this.leftEar,
    required this.rightEar,
    this.notes,
  });

  /// Medido com o protocolo antigo (através do compressor, sem 3/6 kHz): pedir novo teste.
  bool get isOutdated =>
      [...leftEar, ...rightEar].any((p) => p.protocol < AudiometryPoint.currentProtocol) ||
      (leftEar.isEmpty && rightEar.isEmpty);

  /// Retorna a média tritonal (500Hz, 1000Hz, 2000Hz) - padrão clínico
  double calculatePTA([EarSide? side]) {
    // Se não especificado, retorna a média entre as duas orelhas
    if (side == null) {
      return (calculatePTA(EarSide.left) + calculatePTA(EarSide.right)) / 2;
    }

    final points = (side == EarSide.left) ? leftEar : rightEar;
    final relevantFreqs = [500, 1000, 2000];
    
    final matches = points.where((p) => relevantFreqs.contains(p.frequency)).toList();
    if (matches.isEmpty) return 0.0;
    
    final sum = matches.fold(0.0, (prev, curr) => prev + curr.threshold);
    return sum / matches.length;
  }

  /// Converte para Map para compatibilidade com Charting (FL Chart/Syncfusion)
  Map<int, double> toChartData(EarSide side, {ConductionType type = ConductionType.air}) {
    final points = (side == EarSide.left) ? leftEar : rightEar;
    return {
      for (var p in points.where((p) => p.conduction == type)) 
        p.frequency: p.threshold
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'date': date.toIso8601String(),
    'left_ear': leftEar.map((e) => e.toJson()).toList(),
    'right_ear': rightEar.map((e) => e.toJson()).toList(),
    'notes': notes,
  };

  factory Audiogram.fromJson(Map<String, dynamic> json) => Audiogram(
    id: json['id'] ?? '',
    patientId: json['patient_id'],
    date: DateTime.parse(json['created_at']),
    leftEar: (json['left_ear'] as List).map((e) => AudiometryPoint.fromJson(e)).toList(),
    rightEar: (json['right_ear'] as List).map((e) => AudiometryPoint.fromJson(e)).toList(),
    notes: json['notes'],
  );
}
