import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as ffi;
import 'package:flutter/foundation.dart';

// Biblioteca nativa (cpp/): Oboe no Android; no Windows só o grafo, sem saída de áudio.
final ffi.DynamicLibrary _lib = Platform.isAndroid
    ? ffi.DynamicLibrary.open('libdsp_audio_engine.so')
    : Platform.isWindows
        ? ffi.DynamicLibrary.open('dsp_audio_engine.dll')
        : Platform.isIOS
            ? ffi.DynamicLibrary.process()
            : throw UnsupportedError('Unsupported platform');

/// Struct opaca EngineContext do C++ (cpp/native_bridge.cpp).
final class EngineContext extends ffi.Opaque {}

final ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>> _pDestroy =
    _lib.lookup('destroy_engine');
final _finalizer = ffi.NativeFinalizer(_pDestroy);

typedef _CtxVoidC = ffi.Void Function(ffi.Pointer<EngineContext>);
typedef _CtxVoid = void Function(ffi.Pointer<EngineContext>);
typedef _CtxFloatC = ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Float);
typedef _CtxFloat = void Function(ffi.Pointer<EngineContext>, double);
typedef _CtxIntC = ffi.Void Function(ffi.Pointer<EngineContext>, ffi.Int32);
typedef _CtxInt = void Function(ffi.Pointer<EngineContext>, int);
typedef _SampleC = ffi.Void Function(
    ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Int32, ffi.Float, ffi.Int32);
typedef _Sample = void Function(ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, int, double, int);
typedef _EqC = ffi.Void Function(
    ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Pointer<ffi.Float>, ffi.Int32);
typedef _Eq = void Function(
    ffi.Pointer<EngineContext>, ffi.Pointer<ffi.Float>, ffi.Pointer<ffi.Float>, int);

/// Ponte FFI para o motor nativo. Os símbolos são procurados uma vez só (antes, cada chamada
/// fazia um `lookupFunction` novo). Todo símbolo usado aqui existe em `cpp/native_bridge.cpp`.
class NativeDSPBridge implements ffi.Finalizable {
  late final ffi.Pointer<EngineContext> _ctx;

  late final _start = _lib.lookupFunction<ffi.Bool Function(ffi.Pointer<EngineContext>),
      bool Function(ffi.Pointer<EngineContext>)>('start_engine');
  late final _stop = _lib.lookupFunction<_CtxVoidC, _CtxVoid>('stop_engine');
  late final _setTarget = _lib.lookupFunction<_SampleC, _Sample>('set_target_sample');
  late final _setNoiseSample = _lib.lookupFunction<_SampleC, _Sample>('set_noise_sample');
  late final _setMaskerGain = _lib.lookupFunction<_CtxFloatC, _CtxFloat>('set_masker_gain');
  late final _setPanning = _lib.lookupFunction<_CtxFloatC, _CtxFloat>('set_target_panning');
  late final _silenceAll = _lib.lookupFunction<_CtxVoidC, _CtxVoid>('silence_all');
  late final _setEqTargets = _lib.lookupFunction<_EqC, _Eq>('set_eq_targets');
  late final _setBypass = _lib.lookupFunction<_CtxIntC, _CtxInt>('set_dsp_bypass');
  late final _resetLimiterHits = _lib.lookupFunction<_CtxVoidC, _CtxVoid>('reset_limiter_hits');
  late final _limiterHits = _lib.lookupFunction<ffi.Int32 Function(ffi.Pointer<EngineContext>),
      int Function(ffi.Pointer<EngineContext>)>('get_limiter_hits');
  late final _framesRemaining = _lib.lookupFunction<ffi.Int32 Function(ffi.Pointer<EngineContext>),
      int Function(ffi.Pointer<EngineContext>)>('get_target_frames_remaining');
  late final _stimulusNs = _lib.lookupFunction<ffi.Int64 Function(ffi.Pointer<EngineContext>),
      int Function(ffi.Pointer<EngineContext>)>('get_stimulus_timestamp_ns');
  late final _nowNs = _lib.lookupFunction<ffi.Int64 Function(ffi.Pointer<EngineContext>),
      int Function(ffi.Pointer<EngineContext>)>('get_current_timestamp_ns');
  late final _disconnected = _lib.lookupFunction<ffi.Bool Function(ffi.Pointer<EngineContext>),
      bool Function(ffi.Pointer<EngineContext>)>('is_device_disconnected');
  late final _latency = _lib.lookupFunction<ffi.Double Function(ffi.Pointer<EngineContext>),
      double Function(ffi.Pointer<EngineContext>)>('get_latency_ms');
  late final _xruns = _lib.lookupFunction<ffi.Int32 Function(ffi.Pointer<EngineContext>),
      int Function(ffi.Pointer<EngineContext>)>('get_xrun_count');
  late final _dspLoad = _lib.lookupFunction<ffi.Float Function(ffi.Pointer<EngineContext>),
      double Function(ffi.Pointer<EngineContext>)>('get_dsp_load');

  NativeDSPBridge() {
    _ctx = _lib.lookupFunction<ffi.Pointer<EngineContext> Function(),
        ffi.Pointer<EngineContext> Function()>('create_engine')();
    try {
      final clock = _lib.lookupFunction<ffi.Pointer<ffi.Utf8> Function(),
          ffi.Pointer<ffi.Utf8> Function()>('get_clock_info')();
      debugPrint("Native Engine Loaded. Clock: ${clock.toDartString()}");
    } catch (_) {
      debugPrint("Native Load Warning: Diagnostic symbols missing.");
    }
    _finalizer.attach(this, _ctx.cast(), detach: this);
  }

  bool startHardwareAudio() => _start(_ctx);
  void stopHardwareAudio() => _stop(_ctx);

  /// Palavra/tom (mono). [volume] linear.
  void setTargetSample(ffi.Pointer<ffi.Float> data, int length, double volume) =>
      _setTarget(_ctx, data, length, volume, 0);

  /// Ruído/masker (mono), opcionalmente em loop.
  void setNoiseSample(ffi.Pointer<ffi.Float> data, int length, double volume, bool loop) =>
      _setNoiseSample(_ctx, data, length, volume, loop ? 1 : 0);

  void setMaskerGain(double linear) => _setMaskerGain(_ctx, linear);
  void setTargetPanning(double panning) => _setPanning(_ctx, panning);
  void silenceAll() => _silenceAll(_ctx);

  /// Ganhos-alvo (dB) por orelha nas 8 bandas de [AudibilityProfile.bands].
  void setEqTargets(List<double> leftDb, List<double> rightDb) {
    final left = ffi.calloc<ffi.Float>(leftDb.length);
    final right = ffi.calloc<ffi.Float>(rightDb.length);
    try {
      left.asTypedList(leftDb.length).setAll(0, leftDb);
      right.asTypedList(rightDb.length).setAll(0, rightDb);
      _setEqTargets(_ctx, left, right, leftDb.length);
    } finally {
      ffi.calloc.free(left);
      ffi.calloc.free(right);
    }
  }

  /// true = sem EQ (tons de medição e calibração).
  void setDspBypass(bool bypass) => _setBypass(_ctx, bypass ? 1 : 0);

  int getLimiterHits() => _limiterHits(_ctx);
  void resetLimiterHits() => _resetLimiterHits(_ctx);
  int getTargetFramesRemaining() => _framesRemaining(_ctx);
  int getStimulusTimestampNs() => _stimulusNs(_ctx);
  int getCurrentTimestampNs() => _nowNs(_ctx);
  bool isDeviceDisconnected() => _disconnected(_ctx);
  double getLatencyMs() => _latency(_ctx);
  int getXRunCount() => _xruns(_ctx);
  double getDspLoad() => _dspLoad(_ctx);

  void dispose() {
    _finalizer.detach(this);
    stopHardwareAudio();
    _lib.lookupFunction<_CtxVoidC, _CtxVoid>('destroy_engine')(_ctx);
  }
}
