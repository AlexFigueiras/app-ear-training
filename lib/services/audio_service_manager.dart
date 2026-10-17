import 'package:ear_training/audio_engine/audio_engine.dart';
import 'package:flutter/foundation.dart';

/// Centralizador do Gerenciamento de Áudio [ORQUESTRADOR]
/// Garante o controle estrito do Ciclo de Vida do Motor C++/Dart.
class AudioServiceManager {
  static final AudioServiceManager _instance = AudioServiceManager._internal();
  factory AudioServiceManager() => _instance;

  final AudioRehabEngine _engine = AudioRehabEngine();

  AudioServiceManager._internal();

  AudioRehabEngine get engine => _engine;

  /// Silêncio imediato (alvo, ruído e tom) sem desligar o stream. Chamado ao sair de cada tela
  /// de treino, ao ir para segundo plano e ao desconectar o fone.
  void silenceAll() {
    try {
      _engine.silenceAll();
    } catch (e) {
      debugPrint("[AUDIO_MANAGER] Erro ao silenciar: $e");
    }
  }

  /// Silencia e desliga o stream de áudio (libera o hardware).
  void forceStopAll() {
    try {
      _engine.stop();
      debugPrint("[AUDIO_MANAGER] forceStopAll executado: recursos liberados.");
    } catch (e) {
      debugPrint("[AUDIO_MANAGER] Erro durante forceStopAll: $e");
    }
  }

  /// Inicializa o motor clínico com o audiograma atual
  Future<void> initializeEngineForUser(dynamic audiogram) async {
    await _engine.initializeEngine(audiogram);
  }

  /// Liberação absoluta de memória [NATIVE-DSP-FFI]
  void dispose() {
    forceStopAll();
  }
}
