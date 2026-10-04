import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import '../models/audiogram.dart';
import '../services/tts_service.dart';
import 'package:flutter/foundation.dart';
import 'native_engine.dart';

/// Motor de Áudio Central para Reabilitação Auditiva
class AudioRehabEngine {
  static final AudioRehabEngine _instance = AudioRehabEngine._internal();
  factory AudioRehabEngine() => _instance;
  bool _isInitialized = false;
  String? _securePatientId;
  Audiogram? _currentAudiogram;

  final _nativeBridge = NativeDSPBridge();
  final GoogleTTSService _tts = GoogleTTSService();

  // Calibração: 0dB HL -> 0.0001 linear. 80dB HL -> 1.0 linear.
  static const double _kRefDb = 80.0;
  static const double _fs = 48000.0; // Sample Rate padrão do Engine

  AudioRehabEngine._internal();

  Future<void> restartHardwareAudio() async {
    _nativeBridge.stopHardwareAudio();
    await Future.delayed(const Duration(milliseconds: 200));
    _nativeBridge.startHardwareAudio();
    debugPrint("[ENGINE_REINIT] Hardware Audio Stream Restarted (EXCLUSIVE MODE ACTIVE)");
  }

  Future<void> initializeEngine(Audiogram audiogram) async {
    _securePatientId = audiogram.patientId;
    _currentAudiogram = audiogram;
    _nativeBridge.startHardwareAudio();
    _isInitialized = true;

    // Configura DSP nativo com perfil audiométrico do paciente
    // Passa frequências e Half-Gain para cada ponto do audiograma (média L+R)
    _applyAudiogramProfileToDsp(audiogram);

    debugPrint("AudioRehabEngine Inicializado (Native Stereo DSP | Adaptive Clinical EQ)");
  }

  void _applyAudiogramProfileToDsp(Audiogram audiogram) {
    final combined = <int, double>{};
    for (final p in audiogram.leftEar) {
      combined[p.frequency] = (combined[p.frequency] ?? 0) + p.threshold;
    }
    for (final p in audiogram.rightEar) {
      combined[p.frequency] = (combined[p.frequency] ?? 0) + p.threshold;
    }

    // Calcula Half-Gain para cada frequência (média L+R / 2)
    final freqList = combined.keys.toList()..sort();
    if (freqList.isEmpty) return;

    final freqPtr = calloc<ffi.Float>(freqList.length);
    final gainPtr = calloc<ffi.Float>(freqList.length);
    for (int i = 0; i < freqList.length; i++) {
      final freq = freqList[i];
      final countEars = (audiogram.leftEar.any((p) => p.frequency == freq) ? 1 : 0) +
                        (audiogram.rightEar.any((p) => p.frequency == freq) ? 1 : 0);
      final avgThreshold = combined[freq]! / countEars;
      freqPtr[i] = freq.toDouble();
      gainPtr[i] = (avgThreshold / 2.0).clamp(0.0, 30.0); // Half-Gain, max 30 dB
    }

    _nativeBridge.setAudiogramProfile(freqPtr, gainPtr, freqList.length);
    calloc.free(freqPtr);
    calloc.free(gainPtr);
  }

  double getNativeLatencyMs() => _nativeBridge.getLatencyMs();
  int getLastStimulusTimestampNs() => _nativeBridge.getStimulusTimestampNs();
  int getNativeCurrentTimestampNs() => _nativeBridge.getCurrentTimestampNs();
  
  NativeDSPBridge get native => _nativeBridge; 

  /// Regra de Meio Ganho (Half-Gain) [AUDIOLOGIA]
  /// Gain = Loss / 2
  double getCompensatoryGain(double frequencyHz) {
    if (_currentAudiogram == null) return 0.0;
    
    // Busca a perda média para a frequência alvo (L+R)
    final leftPoint = _currentAudiogram!.leftEar.firstWhere(
      (p) => p.frequency >= frequencyHz, orElse: () => _currentAudiogram!.leftEar.last
    );
    final rightPoint = _currentAudiogram!.rightEar.firstWhere(
      (p) => p.frequency >= frequencyHz, orElse: () => _currentAudiogram!.rightEar.last
    );
    
    double avgLoss = (leftPoint.threshold + rightPoint.threshold) / 2.0;
    return avgLoss / 2.0; // REGRA DE OURO
  }

  /// NÍVEL 2: Discriminação Fonêmica com EQ Dinâmico
  Future<void> playPhonemicStimulus({
    required String text,
    required double freqBand,
    double extraBoostDb = 0.0,
  }) async {
    _verifySecurityScope();

    // 1. Calcula Ganho Clínico (Half-Gain Rule + boost adaptativo)
    double clinicalGainDb = getCompensatoryGain(freqBand) + extraBoostDb;
    // Converte dB para linear e aplica ao volume do sample (clamp a +12 dB = 4x)
    double gainLinear = math.pow(10, clinicalGainDb / 20).toDouble().clamp(1.0, 4.0);

    // 2. Síntese de Fala
    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    Float32List samples = _convertInt16ToFloat32(bytes);

    // 3. Carrega e executa no Native DSP com ganho clínico real
    _loadSampleToNative(samples, isTarget: true, volume: gainLinear);

    debugPrint("ESTÍMULO N2: '$text' | Freq: $freqBand Hz | Gain EQ: +${clinicalGainDb.toStringAsFixed(1)} dB (${gainLinear.toStringAsFixed(2)}x)");
  }

  /// NÍVEL 3: Atenção Espacial (Panning Binaural)
  Future<void> playSpatialStimulus({
    required String text,
    required double panning, // -1.0 a 1.0
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();

    // 1. Configura Panning Nativo
    _nativeBridge.setTargetPanning(panning);

    // 2. Aplica EQ de Meio Ganho
    double gainDb = getCompensatoryGain(freqBand);
    double gainLinear = math.pow(10, gainDb / 20).toDouble().clamp(1.0, 4.0);

    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    Float32List samples = _convertInt16ToFloat32(bytes);

    // 3. Carrega no Mixer com ganho clínico real
    _loadSampleToNative(samples, isTarget: true, volume: gainLinear);

    debugPrint("ESTÍMULO ESPACIAL: '$text' | Pan: $panning | EQ: +${gainDb.toStringAsFixed(1)} dB (${gainLinear.toStringAsFixed(2)}x)");
  }



  /// CALIBRAÇÃO: Tom senoidal puro para ajuste de hardware
  Future<void> playCalibrationTone({
    double frequencyHz = 1000.0,
    double durationSeconds = 1.0,
  }) async {
    // 1. Garante que o hardware esteja ativo (mesmo sem audiograma inicial)
    if (!_isInitialized) _nativeBridge.startHardwareAudio();

    // 2. Gera Senoide
    final int numSamples = (durationSeconds * _fs).toInt();
    final Float32List samples = Float32List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      samples[i] = math.sin(2 * math.pi * frequencyHz * i / _fs);
    }

    // 3. Carrega no motor nativo
    _loadSampleToNative(samples, isTarget: true);
    
    debugPrint("CALIBRAÇÃO: Tom de $frequencyHz Hz emitido por $durationSeconds segundos.");
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado [AMBIENTE HOSTIL]
  Future<void> playCocktailStimulus({
    required String text,
    required double snrDb,
    required String noiseEnvironment,
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();

    // 1. Configura Intensidade do Ruído (relação SNR → linear)
    double noiseIntensity = math.pow(10, (-snrDb) / 20).toDouble();
    _nativeBridge.setNoiseIntensity(noiseIntensity.clamp(0.0, 1.0));

    // 2. Aplica EQ Clínico no Alvo + ganho real aplicado ao volume do sample
    double clinicalGainDb = getCompensatoryGain(freqBand);
    double gainLinear = math.pow(10, clinicalGainDb / 20).toDouble().clamp(1.0, 4.0);

    // 3. Síntese
    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    Float32List samples = _convertInt16ToFloat32(bytes);

    // 4. Carrega no motor nativo com ganho clínico real
    _loadSampleToNative(samples, isTarget: true, volume: gainLinear);

    debugPrint("MISTURA COQUETEL: ENV=$noiseEnvironment | SNR=$snrDb dB | EQ: +${clinicalGainDb.toStringAsFixed(1)} dB");
  }

  void _loadSampleToNative(Float32List samples, {bool isTarget = true, double volume = 1.0}) {
    final pointer = calloc<ffi.Float>(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pointer[i] = samples[i];
    }

    if (isTarget) {
      _nativeBridge.setTargetSample(pointer, samples.length, volume, false);
    } else {
      _nativeBridge.setNoiseSample(pointer, samples.length, 1.0, true);
    }
    calloc.free(pointer);
  }

  Float32List _convertInt16ToFloat32(Uint8List bytes) {
    int offset = 0;
    if (bytes.length > 44 && String.fromCharCodes(bytes.sublist(0, 4)) == "RIFF") {
      offset = 44;
    }
    final int16List = bytes.buffer.asInt16List(offset);
    final floatList = Float32List(int16List.length);
    for (int i = 0; i < int16List.length; i++) {
      floatList[i] = int16List[i] / 32768.0;
    }
    return floatList;
  }

  void stop() {
    _nativeBridge.stopHardwareAudio();
  }

  /// NÍVEL 4: O Efeito Coquetel - SNR Balanceado (Alias legado)
  Future<void> playSpeechInNoise({
    required String targetText,
    required double snrDb,
  }) async {
    return playCocktailStimulus(
      text: targetText,
      snrDb: snrDb,
      noiseEnvironment: 'RESTAURANTE',
    );
  }

  /// CALIBRAÇÃO: Tom senoidal puro para ajuste de hardware (Alias para ThresholdTest)
  Future<void> playPureTone({
    required int frequencyHz,
    required int durationMs,
    required EarSide ear,
    required double dbLevel,
  }) async {
    _verifySecurityScope();

    // 1. Gera Senoide
    final int numSamples = (durationMs / 1000.0 * _fs).toInt();
    final Float32List samples = Float32List(numSamples);
    
    // Nível Linear: 10^((dB HL - Ref) / 20)
    double amplitude = math.pow(10, (dbLevel - _kRefDb) / 20).toDouble();

    for (int i = 0; i < numSamples; i++) {
      samples[i] = amplitude * math.sin(2 * math.pi * frequencyHz * i / _fs);
    }

    // 2. Configura Panning (L/R)
    double targetPanning = 0.0;
    if (ear == EarSide.left) targetPanning = -1.0;
    if (ear == EarSide.right) targetPanning = 1.0;
    _nativeBridge.setTargetPanning(targetPanning);

    // 3. Carrega no motor nativo
    _loadSampleToNative(samples, isTarget: true);
    
    debugPrint("PURE TONE: $frequencyHz Hz | $dbLevel dB | Ear: $ear");
  }

  void _verifySecurityScope() {
    if (!_isInitialized) throw Exception("Erro: Motor não inicializado");
  }
}
