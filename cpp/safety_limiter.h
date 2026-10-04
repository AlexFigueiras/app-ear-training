#pragma once
#include <algorithm>
#include <atomic>
#include <cmath>

// Limitador de segurança no fim da cadeia: o pico de saída nunca passa de -1 dBFS.
//
// Ataque instantâneo (o ganho cai na própria amostra que passaria do teto) e liberação de 50 ms.
// Em uso normal ele NÃO deveria agir: o headroom vem da normalização do estímulo no Dart. Por
// isso cada acionamento é contado e aparece no painel de QA. Substitui o soft-knee amostra a
// amostra, que distorcia (clipava) em vez de limitar.
class SafetyLimiter {
public:
    static constexpr float kThreshold = 0.8912509f; // -1 dBFS

    explicit SafetyLimiter(float sampleRate = 48000.0f)
        : releaseCoef_(std::exp(-1.0f / (0.050f * sampleRate))) {}

    // Thread de áudio.
    inline void process(float& left, float& right) {
        const float peak = std::max(std::fabs(left), std::fabs(right));
        const float needed = peak > kThreshold ? kThreshold / peak : 1.0f;
        const float relaxed = 1.0f - (1.0f - gain_) * releaseCoef_;
        gain_ = std::min(relaxed, needed);
        if (needed < 1.0f && !limiting_) hits_.fetch_add(1, std::memory_order_relaxed);
        limiting_ = needed < 1.0f;
        left *= gain_;
        right *= gain_;
    }

    int hits() const { return hits_.load(std::memory_order_relaxed); }
    void resetHits() { hits_.store(0, std::memory_order_relaxed); }

private:
    float releaseCoef_;
    float gain_ = 1.0f;
    bool limiting_ = false;
    std::atomic<int> hits_{0};
};
