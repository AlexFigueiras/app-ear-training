import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../models/audiogram.dart';
import '../services/tts_service.dart';
import 'audibility_profile.dart';
import 'native_engine.dart';
import 'signal_level.dart';
import 'tone_factory.dart';
import 'wav_decoder.dart';

/// Motor de áudio do treino: prepara cada estímulo em Dart (decodifica, normaliza) e entrega ao
/// motor nativo (`cpp/audio_graph.*`), que aplica o EQ por orelha e mixa com o ruído.
class AudioRehabEngine {
  static final AudioRehabEngine _instance = AudioRehabEngine._internal();
  factory AudioRehabEngine() => _instance;
  AudioRehabEngine._internal();

  final _nativeBridge = NativeDSPBridge();
  final GoogleTTSService _tts = GoogleTTSService();
  bool _isInitialized = false;
  AudibilityProfile _profile = AudibilityProfile.flat;

  // Escala relativa dos tons do teste: 0 dB = -80 dBFS; 80 dB = escala cheia (teto).
  static const double _kRefDb = 80.0;
  static const double _fs = 48000.0;

  bool get isInitialized => _isInitialized;
  NativeDSPBridge get native => _nativeBridge;
  AudibilityProfile get profile => _profile;

  double getNativeLatencyMs() => _nativeBridge.getLatencyMs();
  int getLastStimulusTimestampNs() => _nativeBridge.getStimulusTimestampNs();
  int getNativeCurrentTimestampNs() => _nativeBridge.getCurrentTimestampNs();

  Future<void> initializeEngine(Audiogram audiogram) async {
    _nativeBridge.startHardwareAudio();
    _isInitialized = true;
    _profile = AudibilityProfile.fromAudiogram(audiogram);
    _applyEq(_profile);
    debugPrint("AudioRehabEngine: EQ por orelha esq=${_profile.left} dir=${_profile.right}");
  }

  void _applyEq(AudibilityProfile profile) =>
      _nativeBridge.setEqTargets(profile.left, profile.right);

  /// Sintetiza (ou lê do cache), decodifica a 48 kHz e normaliza o RMS da palavra.
  Future<Float32List> _loadSpeech(String text) async {
    final path = await _tts.synthesize(text);
    final bytes = await File(path).readAsBytes();
    return SignalLevel.normalizeRms(WavDecoder.decodeToRate(bytes).samples);
  }

  Duration _durationOf(Float32List samples) =>
      Duration(microseconds: samples.length * 1000000 ~/ _fs);

  /// Prepara o caminho do alvo: EQ do paciente (+ boost agudo), sem bypass, pan e ruído.
  void _prepareSpeech({double boostDb = 0.0, double panning = 0.0, double noise = 0.0}) {
    _applyEq(_profile.withHighBandBoost(boostDb));
    _nativeBridge.setDspBypass(false);
    _nativeBridge.setTargetPanning(panning);
    _nativeBridge.setNoiseIntensity(noise);
  }

  /// Fonêmica. [extraBoostDb] é a dificuldade: ganho extra só nas bandas agudas (>= 3 kHz).
  /// Devolve a duração: a tela só libera a resposta depois que a palavra termina.
  Future<Duration> playPhonemicStimulus({
    required String text,
    required double freqBand,
    double extraBoostDb = 0.0,
  }) async {
    _verifySecurityScope();
    final samples = await _loadSpeech(text);
    _prepareSpeech(boostDb: extraBoostDb);
    _loadSampleToNative(samples);
    debugPrint("ESTÍMULO N2: '$text' | banda $freqBand Hz | boost agudo +${extraBoostDb.toStringAsFixed(1)} dB");
    return _durationOf(samples);
  }

  /// Espacial (provisório: redesenho na Etapa 9 do plano).
  Future<Duration> playSpatialStimulus({
    required String text,
    required double panning,
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    final samples = await _loadSpeech(text);
    _prepareSpeech(panning: panning);
    _loadSampleToNative(samples);
    return _durationOf(samples);
  }

  /// Fala no ruído. O ruído entra depois do EQ, sobre uma fala de RMS conhecido: o SNR pedido
  /// é o entregue, inclusive abaixo de 0 dB (antes travava em 0 dB).
  /// Provisório: ruído branco até a Etapa 7 (ruído de fala/babble).
  Future<Duration> playCocktailStimulus({
    required String text,
    required double snrDb,
    required String noiseEnvironment,
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    final samples = await _loadSpeech(text);
    _prepareSpeech(noise: SignalLevel.whiteNoiseAmplitudeForSnr(snrDb).clamp(0.0, 0.8));
    _loadSampleToNative(samples);
    debugPrint("COQUETEL: SNR=$snrDb dB | ambiente=$noiseEnvironment");
    return _durationOf(samples);
  }

  /// Painel de QA (só debug/profile): a mesma palavra com e sem o EQ do paciente.
  Future<Duration> playQaWord(String text, {required bool withEq}) async {
    if (!_isInitialized) _nativeBridge.startHardwareAudio();
    final samples = await _loadSpeech(text);
    _prepareSpeech();
    _nativeBridge.setDspBypass(!withEq);
    _loadSampleToNative(samples);
    return _durationOf(samples);
  }

  /// Tom de calibração: 1 kHz a -20 dBFS, centralizado, sem EQ, com rampas.
  Future<Duration> playCalibrationTone({
    double frequencyHz = 1000.0,
    double durationSeconds = 1.0,
  }) async {
    if (!_isInitialized) _nativeBridge.startHardwareAudio();
    _prepareTone(panning: 0.0);
    _loadSampleToNative(ToneFactory.sine(
      frequencyHz: frequencyHz,
      seconds: durationSeconds,
      amplitude: ToneFactory.calibrationAmplitude,
      sampleRate: _fs,
    ));
    return Duration(microseconds: (durationSeconds * 1e6).round());
  }

  /// Tom puro do teste de limiar: SEM EQ (bypass) — medir através de processamento invalida o
  /// audiograma. Nível com teto em [_kRefDb] (escala cheia).
  /// [pulsed]: 3 bipes de 250 ms (teste de limiar); senão, tom contínuo de [durationMs].
  Future<Duration> playPureTone({
    required int frequencyHz,
    required int durationMs,
    required EarSide ear,
    required double dbLevel,
    bool pulsed = false,
  }) async {
    _verifySecurityScope();
    final level = math.min(dbLevel, _kRefDb);
    final amplitude = math.pow(10, (level - _kRefDb) / 20).toDouble();
    final samples = pulsed
        ? ToneFactory.pulsed(frequencyHz: frequencyHz.toDouble(), amplitude: amplitude, sampleRate: _fs)
        : ToneFactory.sine(
            frequencyHz: frequencyHz.toDouble(),
            seconds: durationMs / 1000.0,
            amplitude: amplitude,
            sampleRate: _fs,
          );
    _prepareTone(panning: ear == EarSide.left ? -1.0 : (ear == EarSide.right ? 1.0 : 0.0));
    _loadSampleToNative(samples);
    debugPrint("PURE TONE: $frequencyHz Hz | $level dB | $ear");
    return _durationOf(samples);
  }

  /// Duração de uma apresentação pulsada (para as tentativas silenciosas esperarem o mesmo tempo).
  static Duration get pulsedToneDuration => Duration(
      microseconds: ToneFactory.pulsed(frequencyHz: 1000, amplitude: 0).length * 1000000 ~/ 48000);

  void _prepareTone({required double panning}) {
    _nativeBridge.setDspBypass(true);
    _nativeBridge.setTargetPanning(panning);
    _nativeBridge.setNoiseIntensity(0.0);
  }

  void _loadSampleToNative(Float32List samples) {
    final pointer = calloc<ffi.Float>(samples.length);
    try {
      pointer.asTypedList(samples.length).setAll(0, samples);
      _nativeBridge.setTargetSample(pointer, samples.length, 1.0);
    } finally {
      calloc.free(pointer);
    }
  }

  /// Silêncio imediato (alvo, ruído e tom), sem desligar o stream.
  void silenceAll() => _nativeBridge.silenceAll();

  void stop() {
    _nativeBridge.silenceAll();
    _nativeBridge.stopHardwareAudio();
  }

  void _verifySecurityScope() {
    if (!_isInitialized) throw Exception("Erro: Motor não inicializado");
  }
}
