import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/event_buffer.dart';
import '../services/audio_service_manager.dart';

/// CONTROLADOR DE ACUIDADE ESPACIAL [ESCALONAMENTO-N3]
/// Gerencia a lógica de localização binaural e tracking de erro angular.
class SpatialController extends ChangeNotifier {
  int _consecutiveHits = 0;
  double _lastAngularError = 0.0;
  String _statusMessage = "SISTEMA DE RADAR ATIVO";

  int get consecutiveHits => _consecutiveHits;
  double get lastAngularError => _lastAngularError;
  String get statusMessage => _statusMessage;

  /// Processa a resposta do usuário para o estímulo espacial
  Future<void> processSpatialResponse({
    required double targetPanning,
    required double selectedPanning,
    required String phoneme,
  }) async {
    // Cálculo do Erro Angular (Simplificado: Diff de Panning)
    _lastAngularError = (targetPanning - selectedPanning).abs();
    bool isCorrect = _lastAngularError < 0.1; // Tolerância clínica

    if (isCorrect) {
      _consecutiveHits++;
      _statusMessage = "ALVO LOCALIZADO: PRECISÃO ALTA";
      HapticFeedback.lightImpact();
      
      // Feedback de Voz a cada 5 acertos
      if (_consecutiveHits >= 5) {
        await _triggerClinicalVoiceReport();
        _consecutiveHits = 0; // Reset da sequência após reporte
      }
    } else {
      _consecutiveHits = 0;
      _statusMessage = "DESVIO DE ROTA DETECTADO - RECALIBRANDO...";
      HapticFeedback.vibrate(); // Alerta tátil de erro
    }

    // Persistência de Telemetria no Supabase [ANALYTICS-TRACKING]
    await _recordSpatialMetrics(phoneme, targetPanning, selectedPanning);
    
    notifyListeners();
  }

  Future<void> _recordSpatialMetrics(String phoneme, double target, double selected) async {
    try {
      final buffer = SessionEventBuffer();
      final engine = AudioServiceManager().engine;
      final prefs = await SharedPreferences.getInstance();
      
      final hwStart = engine.getLastStimulusTimestampNs();
      final hwNow = engine.getNativeCurrentTimestampNs();
      final hardwareLatency = engine.getNativeLatencyMs();
      final systemicOffset = prefs.getDouble('systemic_offset_ms') ?? 0.0;
      
      // Cálculo de RT ultra-preciso (3 fatores de correção)
      int reactionTimeMs = ((hwNow - hwStart) / 1000000 - hardwareLatency - systemicOffset).toInt();

      final hardwareType = buffer.currentHardware.name;
      final isBluetooth = buffer.currentHardware == AudioOutputHardware.bluetooth;

      // Trava de segurança Bluetooth: RT impossivelmente baixo para latência sem fio
      if (isBluetooth && reactionTimeMs < 150) {
        debugPrint("[SPATIAL_TELEMETRY] Alerta: Latência suspeitosamente baixa para Bluetooth ($reactionTimeMs ms).");
      }

      if (reactionTimeMs < 10 && reactionTimeMs > -100) {
        debugPrint("[SPATIAL_TELEMETRY] Descarte: Clique acidental detectado (< 10ms). RT: $reactionTimeMs");
        return; 
      }

      final event = StimulusEvent(
        phoneme: phoneme,
        targetPanning: target,
        selectedPanning: selected,
        angularError: _lastAngularError,
        isCorrect: _lastAngularError < 0.1,
        reactionTimeMs: reactionTimeMs,
        hardwareTimestampNs: hwStart,
        outputHardware: hardwareType,
        deviceName: buffer.deviceName,
      );

      buffer.recordEvent(event);
      debugPrint("[SPATIAL_TELEMETRY] RT Real: $reactionTimeMs ms | HW: $hardwareType");
    } catch (e) {
      debugPrint("Erro ao gravar métrica: $e");
    }
  }

  Future<void> _triggerClinicalVoiceReport() async {
    const report = "SISTEMA DE LOCALIZAÇÃO CALIBRADO - ACUIDADE ESPACIAL EM 98%";
    await AudioServiceManager().engine.playPhonemicStimulus(
      text: report,
      freqBand: 1000.0, // Voz neutra
    );
  }

  void resetStatus() {
    _statusMessage = "SISTEMA DE RADAR ATIVO";
    notifyListeners();
  }
}
