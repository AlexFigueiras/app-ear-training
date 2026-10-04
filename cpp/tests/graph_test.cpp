// Mixer (cpp/audio_graph.*): bypass, EQ só no alvo, limitador, silêncio, loop, troca de
// buffers e — regra de tempo real — nenhuma alocação dentro do render.
#include <atomic>
#include <cstdlib>
#include <new>
#include <vector>
#include "audio_graph.h"
#include "check.h"

// Conta alocações enquanto g_track está ligado.
static std::atomic<bool> g_track{false};
static std::atomic<int> g_allocations{0};
void* operator new(std::size_t size) {
    if (g_track.load()) g_allocations++;
    void* p = std::malloc(size ? size : 1);
    if (p == nullptr) throw std::bad_alloc();
    return p;
}
void operator delete(void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }

static constexpr float kFs = 48000.0f;

static std::vector<float> sine(double freq, int frames, float amp) {
    std::vector<float> s(frames);
    for (int i = 0; i < frames; i++) s[i] = amp * (float)std::sin(2.0 * M_PI * freq * i / kFs);
    return s;
}

static std::vector<float> render(AudioGraph& g, int frames) {
    std::vector<float> out(2 * frames);
    g.render(out.data(), frames);
    return out;
}

static float peak(const std::vector<float>& v, int from = 0) {
    float p = 0.0f;
    for (size_t i = from; i < v.size(); i++) p = std::max(p, std::fabs(v[i]));
    return p;
}

int main() {
    // 1. Bypass = identidade (tom de medição sai exatamente como foi gerado), pan central.
    {
        AudioGraph g(kFs);
        const float boost[EqDesign::kBands] = {0, 0, 0, 0, 20, 20, 20, 20};
        g.setEqTargets(boost, boost);
        g.setBypass(true);
        const auto tone = sine(4000, 4800, 0.25f);
        g.setTarget(tone.data(), (int)tone.size(), 1.0f);
        const auto out = render(g, 4800);
        double maxError = 0.0;
        for (int i = 0; i < 4800; i++) {
            maxError = std::max(maxError, (double)std::fabs(out[2 * i] - tone[i]));
            maxError = std::max(maxError, (double)std::fabs(out[2 * i + 1] - tone[i]));
        }
        CHECK(maxError < 1e-6);
        CHECK(g.limiterHits() == 0);
    }

    // 2. EQ age no alvo: +20 dB em 4 kHz.
    {
        AudioGraph g(kFs);
        const float boost[EqDesign::kBands] = {0, 0, 0, 0, 20, 20, 20, 20};
        g.setEqTargets(boost, boost);
        const auto tone = sine(4000, 24000, 0.01f);
        g.setTarget(tone.data(), (int)tone.size(), 1.0f);
        const auto out = render(g, 24000);
        CHECK_NEAR(20.0 * std::log10(peak(out, 2 * 12000) / 0.01), 20.0, 1.5);
    }

    // 3. O ruído (masker) NÃO passa pelo EQ: o SNR pedido é o entregue.
    {
        AudioGraph g(kFs);
        const float boost[EqDesign::kBands] = {0, 0, 0, 0, 20, 20, 20, 20};
        g.setEqTargets(boost, boost);
        const auto noise = sine(4000, 24000, 0.01f);
        g.setMasker(noise.data(), (int)noise.size(), 1.0f, true);
        const auto out = render(g, 24000);
        CHECK_NEAR(peak(out, 2 * 12000), 0.01, 0.0005);
    }

    // 4. Pan: -1 = só esquerda.
    {
        AudioGraph g(kFs);
        g.setPanning(-1.0f);
        const auto tone = sine(1000, 4800, 0.2f);
        g.setTarget(tone.data(), (int)tone.size(), 1.0f);
        const auto out = render(g, 4800);
        float right = 0.0f, left = 0.0f;
        for (int i = 0; i < 4800; i++) {
            left = std::max(left, std::fabs(out[2 * i]));
            right = std::max(right, std::fabs(out[2 * i + 1]));
        }
        CHECK(left > 0.19f);
        CHECK(right == 0.0f);
    }

    // 5. Limitador: sinal 4x acima da escala nunca passa de -1 dBFS, e o acionamento é contado.
    {
        AudioGraph g(kFs);
        const auto loud = sine(500, 4800, 4.0f);
        g.setTarget(loud.data(), (int)loud.size(), 1.0f);
        const auto out = render(g, 4800);
        CHECK(peak(out) <= SafetyLimiter::kThreshold + 1e-6f);
        CHECK(g.limiterHits() > 0);
    }

    // 6. Silêncio: depois do fade (5 ms) a saída é zero, inclusive o ruído.
    {
        AudioGraph g(kFs);
        const auto tone = sine(1000, 48000, 0.3f);
        g.setTarget(tone.data(), (int)tone.size(), 1.0f);
        g.setMasker(tone.data(), (int)tone.size(), 1.0f, true);
        g.setNoiseAmplitude(0.1f);
        render(g, 1000);
        g.silenceAll();
        const auto out = render(g, 2000);
        CHECK(peak(out, 2 * (BufferSource::kFadeFrames + 300)) == 0.0f);
        // Sem degrau: a primeira amostra depois do silêncio pedido ainda é próxima da anterior.
        CHECK(std::fabs(out[0]) < 0.7f);
    }

    // 7. Loop sem emenda: ruído em loop com número inteiro de períodos não tem salto.
    {
        AudioGraph g(kFs);
        const auto loop = sine(1000, 480, 0.5f); // 10 períodos exatos
        g.setMasker(loop.data(), (int)loop.size(), 1.0f, true);
        const auto out = render(g, 4800);
        double maxStep = 0.0;
        for (int i = 1; i < 4800; i++) maxStep = std::max(maxStep, (double)std::fabs(out[2 * i] - out[2 * i - 2]));
        CHECK(maxStep < 0.07); // degrau máximo de um seno de 1 kHz amostrado a 48 kHz ≈ 0,065
        CHECK(peak(out, 2 * 4000) > 0.45f); // continua tocando depois de 10 voltas
    }

    // 8. Fim do alvo: framesRemaining chega a zero e o onset foi marcado.
    {
        AudioGraph g(kFs);
        const auto tone = sine(1000, 1000, 0.2f);
        g.setTarget(tone.data(), (int)tone.size(), 1.0f);
        CHECK(g.targetFramesRemaining() == 1000);
        render(g, 2000);
        CHECK(g.targetFramesRemaining() == 0);
        CHECK(g.lastOnsetNs() > 0);
    }

    // 9. Troca de buffers repetida (o Dart publica, a thread de áudio aposenta, o Dart libera)
    //    e zero alocação dentro do render.
    {
        AudioGraph g(kFs);
        const auto tone = sine(700, 2000, 0.2f);
        int renderAllocations = 0;
        for (int round = 0; round < 200; round++) {
            g.setTarget(tone.data(), (int)tone.size(), 1.0f);
            if (round % 3 == 0) g.setMasker(tone.data(), (int)tone.size(), 0.5f, true);
            if (round % 50 == 0) {
                const float profile[EqDesign::kBands] = {0, 0, 1, 3, 6, 9, 12, 12};
                g.setEqTargets(profile, profile);
            }
            if (round % 7 == 0) g.silenceAll();
            std::vector<float> out(2 * 777);
            g_allocations = 0;
            g_track = true;
            g.render(out.data(), 777);
            g_track = false;
            renderAllocations += g_allocations.load();
        }
        CHECK(renderAllocations == 0);
    }

    return checkSummary("graph_test");
}
