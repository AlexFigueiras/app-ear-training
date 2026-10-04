import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as ffi;
import 'package:flutter/foundation.dart';

// Instanciação da Biblioteca Nativa Shared Object
final ffi.DynamicLibrary _lib = Platform.isAndroid 
    ? ffi.DynamicLibrary.open('libdsp_audio_engine.so') 
    : Platform.isWindows 
      ? ffi.DynamicLibrary.open('dsp_audio_engine.dll') 
      : Platform.isIOS
        ? ffi.DynamicLibrary.process() 
        : throw UnsupportedError('Unsupported platform');

// Classe Opaca correspondente à struct EngineContext do C++
final class EngineContext extends ffi.Opaque {}

// Definição do Garbage Collector Híbrido (NativeFinalizer)
// O callback do NativeFinalizer deve receber um Pointer<Void>
final ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>> pFreeEngine = 
  _lib.lookup('destroy_engine');
final finalizer = ffi.NativeFinalizer(pFreeEngine);

// --- C-Signatures & Dart Callbacks ---
typedef CreateEngineC = ffi.Pointer<EngineContext> Function();
typedef CreateEngineDart = ffi.Pointer<EngineContext> Function();
final CreateEngineDart _createEngine = _lib.lookupFunction<CreateEngineC, CreateEngineDart>('create_engine');

typedef StartEngineC = ffi.Bool Function(ffi.Pointer<EngineContext>);
typedef StartEngineDart = bool Function(ffi.Pointer<EngineContext>);
final StartEngineDart _startEngine = _lib.lookupFunction<StartEngineC, StartEngineDart>('start_engine');

typedef StopEngineC = ffi.Void Function(ffi.Pointer<EngineContext>);
typedef StopEngineDart = void Function(ffi.Pointer<EngineContext>);
final StopEngineDart _stopEngine = _lib.lookupFunction<StopEngineC, StopEngineDart>('stop_engine');

/// Abstração FFI Limpa e de Performance para integração com a UI.
class NativeDSPBridge implements ffi.Finalizable {
  late final ffi.Pointer<EngineContext> _enginePtr;

  NativeDSPBridge() {
    _enginePtr = _createEngine();
    
    // LOG DE SEGURANÇA: Validação de Carregamento e Cronometria Nativa
    try {
      final getClock = _lib.lookupFunction<
        ffi.Pointer<ffi.Int8> Function(),
        ffi.Pointer<ffi.Int8> Function()
      >('get_clock_info');
      
      final clockInfo = getClock().cast<ffi.Utf8>().toDartString();
      debugPrint("Native Engine Loaded Successfully.");
      debugPrint("Clock Precision: $clockInfo");
    } catch (_) {
      debugPrint("Native Load Warning: Diagnostic symbols missing.");
    }

    // Prevenção de Leaks: quando este objeto Dart for coletado, destrói o engine C++.
    finalizer.attach(this, _enginePtr.cast(), detach: this);
  }

  /// Hook Nativo: Dá ignição na thread do Oboe no modo EXCLUSIVE
  bool startHardwareAudio() {
    return _startEngine(_enginePtr);
  }

  /// Desliga o fluxo contínuo de áudio (Desbloqueia os recursos MMAP)
  void stopHardwareAudio() {
    _stopEngine(_enginePtr);
  }

  // --- Novos canais de controle clínico ---

  void setTestTone(double frequency, double amplitude, bool left, bool right) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Float, ffi.Float, ffi.Int32, ffi.Int32),
        void Function(ffi.Pointer<EngineContext>, double, double, int, int)
    >('set_test_tone');
    func(_enginePtr, frequency, amplitude, left ? 1 : 0, right ? 1 : 0);
  }

  void setTargetSample(ffi.Pointer<ffi.Float> data, int length, double volume, bool loop) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Int32, ffi.Float, ffi.Int32),
        void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, int, double, int)
    >('set_target_sample');
    func(_enginePtr, data, length, volume, loop ? 1 : 0);
  }

  void setNoiseSample(ffi.Pointer<ffi.Float> data, int length, double volume, bool loop) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Int32, ffi.Float, ffi.Int32),
        void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, int, double, int)
    >('set_noise_sample');
    func(_enginePtr, data, length, volume, loop ? 1 : 0);
  }

  void setNoiseIntensity(double intensity) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Float),
        void Function(ffi.Pointer<EngineContext>, double)
    >('set_noise_intensity');
    func(_enginePtr, intensity);
  }

  /// Zera alvo, ruído e tom de teste sem desligar o stream.
  void silenceAll() {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>),
        void Function(ffi.Pointer<EngineContext>)
    >('silence_all');
    func(_enginePtr);
  }

  void setTargetPanning(double panning) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Float),
        void Function(ffi.Pointer<EngineContext>, double)
    >('set_target_panning');
    func(_enginePtr, panning);
  }

  /// Recupera o momento exato que o estímulo sonou na Orelha (nanosegundos)
  int getStimulusTimestampNs() {
    final func = _lib.lookupFunction<
        ffi.Int64 Function(ffi.Pointer<EngineContext>),
        int Function(ffi.Pointer<EngineContext>)
    >('get_stimulus_timestamp_ns');
    return func(_enginePtr);
  }

  /// Verifica se o Hardware reportou desconexão de fone de ouvido
  bool isDeviceDisconnected() {
    final func = _lib.lookupFunction<
        ffi.Bool Function(ffi.Pointer<EngineContext>),
        bool Function(ffi.Pointer<EngineContext>)
    >('is_device_disconnected');
    return func(_enginePtr);
  }

  /// Retorna a latência atual do hardware em ms
  double getLatencyMs() {
    final func = _lib.lookupFunction<
        ffi.Double Function(ffi.Pointer<EngineContext>),
        double Function(ffi.Pointer<EngineContext>)
    >('get_latency_ms');
    return func(_enginePtr);
  }

  /// Retorna o contador de falhas de áudio (Underruns)
  int getXRunCount() {
    final func = _lib.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<EngineContext>),
        int Function(ffi.Pointer<EngineContext>)
    >('get_xrun_count');
    return func(_enginePtr);
  }

  /// Retorna a carga de CPU dedicada do motor (0.0 a 1.0)
  double getDspLoad() {
    final func = _lib.lookupFunction<
        ffi.Float Function(ffi.Pointer<EngineContext>),
        double Function(ffi.Pointer<EngineContext>)
    >('get_dsp_load');
    return func(_enginePtr);
  }

  /// Consome o estado de compressão (SoftKnee) para diagnóstico visual
  bool consumeSoftKneeFlag() {
    final func = _lib.lookupFunction<
        ffi.Bool Function(ffi.Pointer<EngineContext>),
        bool Function(ffi.Pointer<EngineContext>)
    >('consume_soft_knee_flag');
    return func(_enginePtr);
  }

  /// Retorna o timestamp atual do hardware (nanosegundos)
  int getCurrentTimestampNs() {
    final func = _lib.lookupFunction<
        ffi.Int64 Function(ffi.Pointer<EngineContext>),
        int Function(ffi.Pointer<EngineContext>)
    >('get_current_timestamp_ns');
    return func(_enginePtr);
  }

  /// Configura o Peaking EQ nativo com o perfil audiométrico do paciente
  /// freqs: frequências (Hz), gains: ganhos compensatórios (dB, Half-Gain)
  void setAudiogramProfile(ffi.Pointer<ffi.Float> freqs, ffi.Pointer<ffi.Float> gains, int count) {
    final func = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Pointer<ffi.Float>, ffi.Int32),
        void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Pointer<ffi.Float>, int)
    >('set_audiogram_profile');
    func(_enginePtr, freqs, gains, count);
  }

  void dispose() {
    finalizer.detach(this);
    stopHardwareAudio();
    final destroy = _lib.lookupFunction<
        ffi.Void Function(ffi.Pointer<EngineContext>),
        void Function(ffi.Pointer<EngineContext>)
    >('destroy_engine');
    destroy(_enginePtr);
  }
}

