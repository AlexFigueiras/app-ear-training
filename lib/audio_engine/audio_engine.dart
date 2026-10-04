import 'dart:math' as math;
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import '../models/audiogram.dart';
import '../services/tts_service.dart';
import 'package:flutter/foundation.dart';
import 'native_engine.dart';
import 'tone_factory.dart';
import 'wav_decoder.dart';

/// Motor de Áudio Central para Reabilitação Auditiva
class AudioRehabEngine {
  static final AudioRehabEngine _instance = AudioRehabEngine._internal();
  factory AudioRehabEngine() => _instance;
  bool _isInitialized = false;
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

  /// Sintetiza (ou lê do cache) e decodifica a palavra já na taxa do motor (48 kHz).
  Future<DecodedAudio> _loadSpeech(String text) async {
    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    return WavDecoder.decodeToRate(bytes);
  }

  /// Ganho de banda larga provisório (meio-ganho + boost, teto de +12 dB). Substituído pelo EQ
  /// por orelha e pelo boost só nos agudos na Etapa 3 do plano.
  double _legacyGainLinear(double gainDb) =>
      math.pow(10, gainDb / 20).toDouble().clamp(1.0, 4.0);

  /// NÍVEL 2: Discriminação Fonêmica. Devolve a duração do estímulo: a tela só libera a
  /// resposta depois que a palavra terminou de tocar.
  Future<Duration> playPhonemicStimulus({
    required String text,
    required double freqBand,
    double extraBoostDb = 0.0,
  }) async {
    _verifySecurityScope();
    final clinicalGainDb = getCompensatoryGain(freqBand) + extraBoostDb;
    final audio = await _loadSpeech(text);

    // Sem ruído e no centro: o estado do motor é compartilhado entre telas, e antes o pan de um
    // teste anterior (±1) fazia a palavra tocar num ouvido só.
    _nativeBridge.setNoiseIntensity(0.0);
    _nativeBridge.setTargetPanning(0.0);
    _loadSampleToNative(audio.samples, volume: _legacyGainLinear(clinicalGainDb));

    debugPrint("ESTÍMULO N2: '$text' | Freq: $freqBand Hz | Gain: +${clinicalGainDb.toStringAsFixed(1)} dB");
    return audio.duration;
  }

  /// NÍVEL 3: Atenção Espacial (provisório: redesenho na Etapa 9 do plano).
  Future<Duration> playSpatialStimulus({
    required String text,
    required double panning, // -1.0 a 1.0
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    final gainDb = getCompensatoryGain(freqBand);
    final audio = await _loadSpeech(text);

    _nativeBridge.setNoiseIntensity(0.0);
    _nativeBridge.setTargetPanning(panning);
    _loadSampleToNative(audio.samples, volume: _legacyGainLinear(gainDb));

    debugPrint("ESTÍMULO ESPACIAL: '$text' | Pan: $panning | Gain: +${gainDb.toStringAsFixed(1)} dB");
    return audio.duration;
  }

  /// NÍVEL 4: Fala no ruído (provisório: ruído de fala e SNR exato na Etapa 7 do plano).
  Future<Duration> playCocktailStimulus({
    required String text,
    required double snrDb,
    required String noiseEnvironment,
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    final clinicalGainDb = getCompensatoryGain(freqBand);
    final audio = await _loadSpeech(text);

    final noiseIntensity = math.pow(10, (-snrDb) / 20).toDouble();
    _nativeBridge.setNoiseIntensity(noiseIntensity.clamp(0.0, 1.0));
    _nativeBridge.setTargetPanning(0.0);
    _loadSampleToNative(audio.samples, volume: _legacyGainLinear(clinicalGainDb));

    debugPrint("MISTURA COQUETEL: ENV=$noiseEnvironment | SNR=$snrDb dB | Gain: +${clinicalGainDb.toStringAsFixed(1)} dB");
    return audio.duration;
  }

  /// Tom de calibração: 1 kHz a -20 dBFS (antes era seno em escala cheia, alto demais para
  /// "ajuste até ficar confortável"), centralizado e com rampas para não estalar.
  Future<Duration> playCalibrationTone({
    double frequencyHz = 1000.0,
    double durationSeconds = 1.0,
  }) async {
    if (!_isInitialized) _nativeBridge.startHardwareAudio();
    _nativeBridge.setNoiseIntensity(0.0);
    _nativeBridge.setTargetPanning(0.0);
    final samples = ToneFactory.sine(
      frequencyHz: frequencyHz,
      seconds: durationSeconds,
      amplitude: ToneFactory.calibrationAmplitude,
      sampleRate: _fs,
    );
    _loadSampleToNative(samples);
    return Duration(microseconds: (durationSeconds * 1e6).round());
  }

  /// Tom puro do teste de limiar. Nível nominal em dB relativos (0 dB = -80 dBFS), com teto
  /// em [_kRefDb] (escala cheia): acima disso o som só distorceria.
  Future<Duration> playPureTone({
    required int frequencyHz,
    required int durationMs,
    required EarSide ear,
    required double dbLevel,
  }) async {
    _verifySecurityScope();
    final level = math.min(dbLevel, _kRefDb);
    final samples = ToneFactory.sine(
      frequencyHz: frequencyHz.toDouble(),
      seconds: durationMs / 1000.0,
      amplitude: math.pow(10, (level - _kRefDb) / 20).toDouble(),
      sampleRate: _fs,
    );

    double targetPanning = 0.0;
    if (ear == EarSide.left) targetPanning = -1.0;
    if (ear == EarSide.right) targetPanning = 1.0;
    _nativeBridge.setNoiseIntensity(0.0);
    _nativeBridge.setTargetPanning(targetPanning);
    _loadSampleToNative(samples);

    debugPrint("PURE TONE: $frequencyHz Hz | $level dB | Ear: $ear");
    return Duration(milliseconds: durationMs);
  }

  void _loadSampleToNative(Float32List samples, {double volume = 1.0}) {
    final pointer = calloc<ffi.Float>(samples.length);
    pointer.asTypedList(samples.length).setAll(0, samples);
    _nativeBridge.setTargetSample(pointer, samples.length, volume, false);
    calloc.free(pointer);
  }

  /// Silêncio imediato (alvo, ruído e tom), sem desligar o stream de áudio. Usado ao sair das
  /// telas de treino, ao ir para segundo plano e ao desconectar o fone.
  void silenceAll() {
    _nativeBridge.silenceAll();
  }

  void stop() {
    _nativeBridge.silenceAll();
    _nativeBridge.stopHardwareAudio();
  }

  void _verifySecurityScope() {
    if (!_isInitialized) throw Exception("Erro: Motor não inicializado");
  }
}
