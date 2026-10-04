#include <stdint.h>
#include <chrono>
#include <cstdlib>

#ifdef __ANDROID__
#include "oboe_engine.h"
#define NATIVE_EXPORT __attribute__((visibility("default")))
#else
#include "dsp_engine.h"
#define NATIVE_EXPORT __declspec(dllexport)
#endif

extern "C" {

struct EngineContext {
#ifdef __ANDROID__
    OboeEngine* engine;
#else
    DspEngine* engine;
#endif
};

NATIVE_EXPORT
EngineContext* create_engine() {
    EngineContext* ctx = new EngineContext();
#ifdef __ANDROID__
    ctx->engine = new OboeEngine();
#else
    ctx->engine = new DspEngine(48000.0f);
#endif
    return ctx;
}

// Hook de Ignição Nativa (Inicia o MMAP Oboe no Android)
NATIVE_EXPORT
bool start_engine(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) {
        return ctx->engine->start();
    }
#endif
    return true; // No Windows simulamos sucesso imediato
}

// Hook de Pausa Nativa
NATIVE_EXPORT
void stop_engine(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) {
        ctx->engine->stop();
    }
#endif
}

// Cleanup Determinístico (via NativeFinalizer)
NATIVE_EXPORT
void destroy_engine(EngineContext* ctx) {
    if (ctx) {
        if (ctx->engine) {
#ifdef __ANDROID__
            ctx->engine->stop();
#endif
            delete ctx->engine;
        }
        delete ctx;
    }
}

// --- NOVOS MÉTODOS CLÍNICOS ---

NATIVE_EXPORT
void set_test_tone(EngineContext* ctx, float freq, float amp, int32_t left, int32_t right) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setTestTone(freq, amp, left != 0, right != 0);
#endif
}

NATIVE_EXPORT
void set_target_sample(EngineContext* ctx, float* data, int32_t len, float vol, int32_t loop) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setTargetSample(data, len, vol, loop != 0);
#endif
}

NATIVE_EXPORT
void set_noise_sample(EngineContext* ctx, float* data, int32_t len, float vol, int32_t loop) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setNoiseSample(data, len, vol, loop != 0);
#endif
}

NATIVE_EXPORT
void set_noise_intensity(EngineContext* ctx, float intensity) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setNoiseIntensity(intensity);
#endif
}

NATIVE_EXPORT
void set_target_panning(EngineContext* ctx, float panning) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setTargetPanning(panning);
#endif
}

NATIVE_EXPORT
void silence_all(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->silenceAll();
#endif
}

// Relógio do mesmo domínio de markStimulusOnset (steady_clock), para medir tempo de reação.
// O Dart (NativeDSPBridge.getCurrentTimestampNs) chamava este símbolo, que não existia: a
// tela de calibração travava no primeiro toque.
NATIVE_EXPORT
int64_t get_current_timestamp_ns(EngineContext* ctx) {
    (void)ctx;
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

NATIVE_EXPORT
int64_t get_stimulus_timestamp_ns(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getStimulusTimestampNs();
#endif
    return 0;
}

NATIVE_EXPORT
bool is_device_disconnected(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->isDeviceDisconnected();
#endif
    return false;
}

NATIVE_EXPORT
double get_latency_ms(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getLatencyMs();
#endif
    return 0.0;
}

NATIVE_EXPORT
int32_t get_xrun_count(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getXRunCount();
#endif
    return 0;
}

NATIVE_EXPORT
float get_dsp_load(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getDspLoad();
#endif
    return 0.0f;
}

NATIVE_EXPORT
bool consume_soft_knee_flag(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getDspEngine().consumeSoftKneeFlag();
#endif
    return false;
}

// Configura EQ adaptativo com perfil audiométrico do paciente
NATIVE_EXPORT
void set_audiogram_profile(EngineContext* ctx, float* freqs, float* gains, int32_t count) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->setAudiogramProfile(freqs, gains, count);
#endif
}

NATIVE_EXPORT
const char* get_clock_info() {
    return "std::chrono::high_resolution_clock (nanoseconds)";
}

} // extern "C"
