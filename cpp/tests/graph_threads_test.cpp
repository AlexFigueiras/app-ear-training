// Estresse com duas threads (a do Dart publicando, a de áudio renderizando), para o
// ThreadSanitizer acusar qualquer corrida de dados. Roda também com ASan/UBSan.
#include <atomic>
#include <thread>
#include <vector>
#include "audio_graph.h"
#include "check.h"

int main() {
    AudioGraph graph(48000.0f);
    std::vector<float> tone(3000);
    for (size_t i = 0; i < tone.size(); i++) tone[i] = 0.2f * (float)std::sin(0.13 * (double)i);

    std::atomic<bool> done{false};
    std::thread dart([&] {
        for (int round = 0; round < 3000; round++) {
            graph.setTarget(tone.data(), (int)tone.size(), 1.0f);
            if (round % 4 == 0) graph.setMasker(tone.data(), (int)tone.size(), 0.3f, true);
            if (round % 5 == 0) graph.setMaskerGain(0.1f * (float)(round % 10));
            if (round % 9 == 0) graph.setNoiseAmplitude(0.01f * (float)(round % 3));
            if (round % 11 == 0) graph.setPanning(round % 2 ? -0.5f : 0.5f);
            if (round % 13 == 0) graph.setBypass(round % 2 == 0);
            if (round % 101 == 0) {
                const float profile[EqDesign::kBands] = {0, 0, 1, 3, 6, 9, 12, (float)(round % 20)};
                graph.setEqTargets(profile, profile);
            }
            if (round % 17 == 0) graph.silenceAll();
            (void)graph.targetFramesRemaining();
            (void)graph.limiterHits();
        }
        done = true;
    });

    std::vector<float> out(2 * 192);
    long blocks = 0;
    float maxPeak = 0.0f;
    while (!done.load()) {
        graph.render(out.data(), 192);
        for (float s : out) maxPeak = std::max(maxPeak, std::fabs(s));
        blocks++;
    }
    dart.join();

    CHECK(blocks > 0);
    CHECK(maxPeak <= SafetyLimiter::kThreshold + 1e-6f);
    return checkSummary("graph_threads_test");
}
