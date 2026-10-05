import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../models/audiogram.dart';
import '../services/tts_service.dart';
import '../training/stimulus_bank.dart';
import 'audibility_profile.dart';
import 'masker_bank.dart';
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
  /// Se a voz pedida falhar (ex.: indisponível no Google), usa a voz padrão.
  Future<Float32List> _loadSpeech(String text, {String? voice}) async {
    String path;
    try {
      path = voice == null ? await _tts.synthesize(text) : await _tts.synthesize(text, voiceName: voice);
    } catch (e) {
      if (voice == null) rethrow;
      debugPrint("TTS: voz $voice falhou ($e); usando a padrão.");
      path = await _tts.synthesize(text);
    }
    final bytes = await File(path).readAsBytes();
    return SignalLevel.normalizeRms(WavDecoder.decodeToRate(bytes).samples);
  }

  /// Baixa e guarda no cache a palavra da próxima tentativa enquanto a pessoa responde a atual.
  Future<void> prefetchSpeech(String text, {String? voice}) async {
    try {
      await _loadSpeech(text, voice: voice);
    } catch (_) {
      // Sem rede agora: a tentativa tenta de novo na hora de tocar.
    }
  }

  Duration _durationOf(Float32List samples) =>
      Duration(microseconds: samples.length * 1000000 ~/ _fs);

  /// Prepara o caminho do alvo: EQ do paciente (+ boost agudo), sem bypass e pan. Com [snrDb],
  /// ajusta o ganho do ruído de fundo (que precisa ter sido iniciado com [startMasker]); sem
  /// ele, o ruído fica mudo.
  void _prepareSpeech({double boostDb = 0.0, double panning = 0.0, double? snrDb}) {
    _applyEq(_profile.withHighBandBoost(boostDb));
    _nativeBridge.setDspBypass(false);
    _nativeBridge.setTargetPanning(panning);
    _nativeBridge.setMaskerGain(snrDb == null ? 0.0 : SignalLevel.maskerGainForSnr(snrDb));
  }

  /// Inicia o ruído de fundo em loop (mudo até o primeiro [playCocktailStimulus]). O burburinho
  /// usa 6 frases do TTS; sem rede, cai para o ruído com espectro de fala. Devolve o tipo usado.
  Future<MaskerType> startMasker(MaskerType type) async {
    _verifySecurityScope();
    var used = type;
    Float32List samples;
    if (type == MaskerType.babble) {
      try {
        samples = MaskerBank.babble([
          for (var i = 0; i < MaskerBank.babbleSentences.length; i++)
            await _loadSpeech(MaskerBank.babbleSentences[i], voice: StimulusBank.voices[i % StimulusBank.voices.length]),
        ]);
      } catch (e) {
        debugPrint("Burburinho indisponível ($e); usando ruído de fala.");
        used = MaskerType.speechShaped;
        samples = MaskerBank.speechShapedNoise();
      }
    } else {
      samples = MaskerBank.speechShapedNoise();
    }
    _nativeBridge.setMaskerGain(0.0);
    final pointer = calloc<ffi.Float>(samples.length);
    try {
      pointer.asTypedList(samples.length).setAll(0, samples);
      _nativeBridge.setNoiseSample(pointer, samples.length, 1.0, true);
    } finally {
      calloc.free(pointer);
    }
    return used;
  }

  /// Fonêmica. [extraBoostDb] é a dificuldade: ganho extra só nas bandas agudas (>= 3 kHz).
  /// Devolve a duração: a tela só libera a resposta depois que a palavra termina.
  Future<Duration> playPhonemicStimulus({
    required String text,
    String? voice,
    required double freqBand,
    double extraBoostDb = 0.0,
  }) async {
    _verifySecurityScope();
    final samples = await _loadSpeech(text, voice: voice);
    _prepareSpeech(boostDb: extraBoostDb);
    _loadSampleToNative(samples);
    debugPrint("ESTÍMULO N2: '$text' | banda $freqBand Hz | boost agudo +${extraBoostDb.toStringAsFixed(1)} dB");
    return _durationOf(samples);
  }

  /// Espacial (provisório: redesenho na Etapa 9 do plano).
  Future<Duration> playSpatialStimulus({
    required String text,
    String? voice,
    required double panning,
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    final samples = await _loadSpeech(text, voice: voice);
    _prepareSpeech(panning: panning);
    _loadSampleToNative(samples);
    return _durationOf(samples);
  }

  /// Fala no ruído. Fala e ruído têm o mesmo RMS e o ruído entra depois do EQ: o SNR pedido é o
  /// entregue, inclusive abaixo de 0 dB. O ruído precisa ter sido iniciado com [startMasker].
  Future<Duration> playCocktailStimulus({
    required String text,
    String? voice,
    required double snrDb,
    double freqBand = 4000.0,
  }) async {
    _verifySecurityScope();
    final samples = await _loadSpeech(text, voice: voice);
    _prepareSpeech(snrDb: snrDb);
    _loadSampleToNative(samples);
    debugPrint("COQUETEL: SNR=$snrDb dB");
    return _durationOf(samples);
  }

  /// Voz do teste de dígitos: diferente das vozes do treino, para a medida não "treinar junto".
  static const String dinVoice = 'pt-BR-Wavenet-D';
  static const List<String> _digitWords = [
    'zero', 'um', 'dois', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove',
  ];
  final Map<int, Float32List> _digitCache = {};

  /// Baixa os 10 dígitos antes de o teste começar (para não haver pausa entre trios).
  Future<void> prepareDigits() async {
    for (var d = 0; d <= 9; d++) {
      _digitCache[d] ??= await _loadSpeech(_digitWords[d], voice: dinVoice);
    }
  }

  /// Teste de dígitos no ruído: 3 dígitos com 300 ms entre eles, SEM EQ (a medida não pode
  /// mudar quando o audiograma muda), sobre o ruído de fala iniciado com [startMasker].
  Future<Duration> playDigitTriplet(List<int> digits, double snrDb) async {
    _verifySecurityScope();
    await prepareDigits();
    final gap = Float32List((0.3 * _fs).round());
    final parts = <Float32List>[for (final d in digits) ...[_digitCache[d]!, gap]]..removeLast();
    final triplet = Float32List(parts.fold(0, (n, p) => n + p.length));
    var offset = 0;
    for (final p in parts) {
      triplet.setAll(offset, p);
      offset += p.length;
    }
    _nativeBridge.setDspBypass(true);
    _nativeBridge.setTargetPanning(0.0);
    _nativeBridge.setMaskerGain(SignalLevel.maskerGainForSnr(snrDb));
    _loadSampleToNative(triplet);
    return _durationOf(triplet);
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
    _nativeBridge.setMaskerGain(0.0);
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
