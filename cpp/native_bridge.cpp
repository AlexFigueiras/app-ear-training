#include <stdint.h>
#include <chrono>
#include <cstdlib>
#include "audio_graph.h"

#ifdef __ANDROID__
#include "oboe_engine.h"
#define NATIVE_EXPORT __attribute__((visibility("default")))
#elif defined(_WIN32)
#define NATIVE_EXPORT __declspec(dllexport)
#else
#define NATIVE_EXPORT __attribute__((visibility("default")))
#endif

// Ponte C para o Dart FFI. Todo símbolo chamado em lib/audio_engine/native_engine.dart precisa
// existir aqui (símbolo ausente = crash na hora da chamada).
//
// No Android o AudioGraph é tocado pelo Oboe. Fora dele (Windows/desktop) não há saída de áudio:
// o grafo existe só para a API aceitar as chamadas.
extern "C" {

struct EngineContext {
#ifdef __ANDROID__
    OboeEngine* engine = nullptr;
#else
    AudioGraph* graph = nullptr;
#endif
};

static AudioGraph* graphOf(EngineContext* ctx) {
    if (ctx == nullptr) return nullptr;
#ifdef __ANDROID__
    return ctx->engine ? &ctx->engine->graph() : nullptr;
#else
    return ctx->graph;
#endif
}

NATIVE_EXPORT EngineContext* create_engine() {
    auto* ctx = new EngineContext();
#ifdef __ANDROID__
    ctx->engine = new OboeEngine();
#else
    ctx->graph = new AudioGraph(48000.0f);
#endif
    return ctx;
}

NATIVE_EXPORT bool start_engine(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->start();
#endif
    (void)ctx;
    return true;
}

NATIVE_EXPORT void stop_engine(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) ctx->engine->stop();
#endif
    (void)ctx;
}

NATIVE_EXPORT void destroy_engine(EngineContext* ctx) {
    if (ctx == nullptr) return;
#ifdef __ANDROID__
    if (ctx->engine) {
        ctx->engine->stop();
        delete ctx->engine;
    }
#else
    delete ctx->graph;
#endif
    delete ctx;
}

// --- Estímulos ---

NATIVE_EXPORT void set_target_sample(EngineContext* ctx, float* data, int32_t len, float vol, int32_t loop) {
    (void)loop; // o alvo nunca toca em loop
    if (auto* g = graphOf(ctx)) g->setTarget(data, len, vol);
}

NATIVE_EXPORT void set_noise_sample(EngineContext* ctx, float* data, int32_t len, float vol, int32_t loop) {
    if (auto* g = graphOf(ctx)) g->setMasker(data, len, vol, loop != 0);
}

NATIVE_EXPORT void set_masker_gain(EngineContext* ctx, float linear) {
    if (auto* g = graphOf(ctx)) g->setMaskerGain(linear);
}

NATIVE_EXPORT void set_target_panning(EngineContext* ctx, float panning) {
    if (auto* g = graphOf(ctx)) g->setPanning(panning);
}

// Direção do alvo / do ruído (graus: 0 = frente, +90 = direita). enabled = 0 volta à identidade.
NATIVE_EXPORT void set_target_azimuth(EngineContext* ctx, float deg, int32_t enabled) {
    if (auto* g = graphOf(ctx)) enabled ? g->setTargetAzimuth(deg) : g->disableTargetSpatial();
}

NATIVE_EXPORT void set_masker_azimuth(EngineContext* ctx, float deg, int32_t enabled) {
    if (auto* g = graphOf(ctx)) enabled ? g->setMaskerAzimuth(deg) : g->disableMaskerSpatial();
}

NATIVE_EXPORT void silence_all(EngineContext* ctx) {
    if (auto* g = graphOf(ctx)) g->silenceAll();
}

// --- EQ ---

// leftDb/rightDb: 8 ganhos-alvo (dB) nas bandas 250, 500, 1k, 2k, 3k, 4k, 6k, 8k Hz.
NATIVE_EXPORT void set_eq_targets(EngineContext* ctx, float* leftDb, float* rightDb, int32_t count) {
    if (count != EqDesign::kBands || leftDb == nullptr || rightDb == nullptr) return;
    if (auto* g = graphOf(ctx)) g->setEqTargets(leftDb, rightDb);
}

NATIVE_EXPORT void set_dsp_bypass(EngineContext* ctx, int32_t bypass) {
    if (auto* g = graphOf(ctx)) g->setBypass(bypass != 0);
}

// --- Telemetria / QA ---

NATIVE_EXPORT int32_t get_limiter_hits(EngineContext* ctx) {
    auto* g = graphOf(ctx);
    return g ? g->limiterHits() : 0;
}

NATIVE_EXPORT void reset_limiter_hits(EngineContext* ctx) {
    if (auto* g = graphOf(ctx)) g->resetLimiterHits();
}

NATIVE_EXPORT int32_t get_target_frames_remaining(EngineContext* ctx) {
    auto* g = graphOf(ctx);
    return g ? g->targetFramesRemaining() : 0;
}

NATIVE_EXPORT int64_t get_stimulus_timestamp_ns(EngineContext* ctx) {
    auto* g = graphOf(ctx);
    return g ? g->lastOnsetNs() : 0;
}

// Mesmo relógio (steady_clock) do onset do estímulo.
NATIVE_EXPORT int64_t get_current_timestamp_ns(EngineContext* ctx) {
    (void)ctx;
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

NATIVE_EXPORT bool is_device_disconnected(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->isDeviceDisconnected();
#endif
    (void)ctx;
    return false;
}

NATIVE_EXPORT double get_latency_ms(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getLatencyMs();
#endif
    (void)ctx;
    return 0.0;
}

NATIVE_EXPORT int32_t get_xrun_count(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getXRunCount();
#endif
    (void)ctx;
    return 0;
}

NATIVE_EXPORT float get_dsp_load(EngineContext* ctx) {
#ifdef __ANDROID__
    if (ctx && ctx->engine) return ctx->engine->getDspLoad();
#endif
    (void)ctx;
    return 0.0f;
}

NATIVE_EXPORT const char* get_clock_info() {
    return "std::chrono::steady_clock (nanoseconds)";
}

} // extern "C"
