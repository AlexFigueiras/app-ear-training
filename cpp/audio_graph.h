#pragma once
#include <atomic>
#include <cstdint>
#include "buffer_source.h"
#include "eq_bank.h"
#include "handoff.h"
#include "safety_limiter.h"

// Mixer do BOSYN, sem dependência do Oboe (testável no host, ver cpp/tests/).
//
//   alvo (palavra/tom) -> EQ por orelha (ou bypass) -> pan --+
//   masker (ruído de fala / burburinho, em loop) -------------+--> limitador -1 dBFS -> saída
//
// O ruído entra DEPOIS do EQ: o SNR pedido é o SNR entregue. Tons de medição usam bypass:
// medir limiar através de processamento invalida o audiograma.
class AudioGraph {
public:
    static constexpr int kBlock = 256;

    explicit AudioGraph(float sampleRate = 48000.0f);

    // --- Thread do Dart ---
    void setTarget(const float* data, int frames, float gain) { target_.set(data, frames, 1, gain, false); }
    void setMasker(const float* data, int frames, float gain, bool loop) { masker_.set(data, frames, 1, gain, loop); }
    void setMaskerGain(float linear) { masker_.setGain(linear); }
    void setPanning(float panning) { panning_.store(panning, std::memory_order_release); }
    void setBypass(bool bypass) { bypass_.store(bypass, std::memory_order_release); }
    void setEqTargets(const float* leftDb, const float* rightDb);
    void silenceAll();

    int targetFramesRemaining() const { return target_.framesRemaining(); }
    int limiterHits() const { return limiter_.hits(); }
    void resetLimiterHits() { limiter_.resetHits(); }
    int64_t lastOnsetNs() const { return onsetNs_.load(std::memory_order_acquire); }

    // --- Thread de áudio --- (saída estéreo intercalada; qualquer número de frames)
    void render(float* out, int frames);

private:
    void renderBlock(float* out, int frames);
    static int64_t nowNs();

    float sampleRate_;
    BufferSource target_;
    BufferSource masker_;
    Handoff<EqDesign> eq_;
    EqState eqState_;
    SafetyLimiter limiter_;

    std::atomic<float> panning_{0.0f};
    std::atomic<bool> bypass_{false};
    std::atomic<int64_t> onsetNs_{0};

    // Estado só da thread de áudio.
    bool targetWasActive_ = false;
    float targetL_[kBlock], targetR_[kBlock], maskerL_[kBlock], maskerR_[kBlock];
};
