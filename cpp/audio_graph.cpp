#include "audio_graph.h"
#include <algorithm>
#include <chrono>

AudioGraph::AudioGraph(float sampleRate)
    : sampleRate_(sampleRate), limiter_(sampleRate), targetSpatial_(sampleRate), maskerSpatial_(sampleRate) {
    const float flat[EqDesign::kBands] = {0};
    eq_.publish(new EqDesign(EqDesign::design(flat, flat, sampleRate_)));
}

void AudioGraph::setEqTargets(const float* leftDb, const float* rightDb) {
    eq_.publish(new EqDesign(EqDesign::design(leftDb, rightDb, sampleRate_)));
}

void AudioGraph::silenceAll() {
    target_.stop();
    masker_.stop();
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
    const SpatialParams* targetDir = targetSpatial_.acquire();
    const SpatialParams* maskerDir = maskerSpatial_.acquire();

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
        l *= panL;
        r *= panR;
        if (targetDir != nullptr) targetSpatial_.process(targetDir, l, r);
        float ml = maskerL_[i], mr = maskerR_[i];
        if (maskerDir != nullptr) maskerSpatial_.process(maskerDir, ml, mr);
        l += ml;
        r += mr;
        limiter_.process(l, r);
        out[2 * i] = l;
        out[2 * i + 1] = r;
    }
}
