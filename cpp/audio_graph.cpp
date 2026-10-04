#include "audio_graph.h"
#include <algorithm>
#include <chrono>

AudioGraph::AudioGraph(float sampleRate) : sampleRate_(sampleRate), limiter_(sampleRate) {
    const float flat[EqDesign::kBands] = {0};
    eq_.publish(new EqDesign(EqDesign::design(flat, flat, sampleRate_)));
}

void AudioGraph::setEqTargets(const float* leftDb, const float* rightDb) {
    eq_.publish(new EqDesign(EqDesign::design(leftDb, rightDb, sampleRate_)));
}

void AudioGraph::silenceAll() {
    target_.stop();
    masker_.stop();
    noiseAmplitude_.store(0.0f, std::memory_order_release);
}

int64_t AudioGraph::nowNs() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

void AudioGraph::render(float* out, int frames) {
    for (int offset = 0; offset < frames; offset += kBlock) {
        renderBlock(out + 2 * offset, std::min(kBlock, frames - offset));
    }
}

void AudioGraph::renderBlock(float* out, int frames) {
    const bool targetActive = target_.read(targetL_, targetR_, frames);
    masker_.read(maskerL_, maskerR_, frames);

    const EqDesign* eq = eq_.acquire();
    const bool bypass = bypass_.load(std::memory_order_acquire) || eq == nullptr;
    const float pan = panning_.load(std::memory_order_acquire);
    const float panL = pan <= 0.0f ? 1.0f : 1.0f - pan;
    const float panR = pan >= 0.0f ? 1.0f : 1.0f + pan;
    const float noise = noiseAmplitude_.load(std::memory_order_acquire);
    // Ruído branco uniforme em [-1, 1] sem alocação (minstd_rand é um inteiro de estado).
    const float noiseScale = 2.0f / (float)std::minstd_rand::max();

    // Tempo de reação: marca o instante em que o alvo começa a soar.
    if (targetActive && !targetWasActive_) onsetNs_.store(nowNs(), std::memory_order_release);
    targetWasActive_ = targetActive;

    for (int i = 0; i < frames; i++) {
        float l = targetL_[i];
        float r = targetR_[i];
        if (!bypass) {
            l = eqState_.process(*eq, 0, l);
            r = eqState_.process(*eq, 1, r);
        }
        l = l * panL + maskerL_[i];
        r = r * panR + maskerR_[i];
        if (noise > 0.0f) {
            const float n = noise * ((float)noiseEngine_() * noiseScale - 1.0f);
            l += n;
            r += n;
        }
        limiter_.process(l, r);
        out[2 * i] = l;
        out[2 * i + 1] = r;
    }
}
