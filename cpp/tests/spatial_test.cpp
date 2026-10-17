// Espacialização (cpp/spatializer.h) medida na saída do AudioGraph: diferença de tempo entre
// orelhas (correlação cruzada), diferença de nível (sombra da cabeça), simetria e identidade.
#include <random>
#include <vector>
#include "audio_graph.h"
#include "check.h"

static constexpr float kFs = 48000.0f;

static std::vector<float> render(AudioGraph& g, const std::vector<float>& mono) {
    g.setTarget(mono.data(), (int)mono.size(), 1.0f);
    std::vector<float> out(2 * mono.size());
    g.render(out.data(), (int)mono.size());
    return out;
}

static std::vector<float> noise(int frames, float amp) {
    std::mt19937 rng(7);
    std::uniform_real_distribution<float> dist(-amp, amp);
    std::vector<float> v(frames);
    for (auto& s : v) s = dist(rng);
    return v;
}

static std::vector<float> sine(double f, int frames, float amp) {
    std::vector<float> v(frames);
    for (int i = 0; i < frames; i++) v[i] = amp * (float)std::sin(2.0 * M_PI * f * i / kFs);
    return v;
}

// Atraso (amostras) da orelha esquerda em relação à direita: lag de máxima correlação.
static double leftLagSamples(const std::vector<float>& out, int from, int to) {
    double best = -1e30;
    int bestLag = 0;
    for (int lag = -48; lag <= 48; lag++) {
        double sum = 0.0;
        for (int i = from; i < to; i++) sum += (double)out[2 * i] * out[2 * (i - lag) + 1];
        if (sum > best) {
            best = sum;
            bestLag = lag;
        }
    }
    return bestLag;
}

static double rmsDb(const std::vector<float>& out, int channel, int from, int to) {
    double e = 0.0;
    for (int i = from; i < to; i++) e += (double)out[2 * i + channel] * out[2 * i + channel];
    return 10.0 * std::log10(e / (to - from));
}

int main() {
    const int n = 48000;

    // 1. Fonte à direita (+90°): a orelha esquerda atrasa ~31 amostras (Woodworth, ~0,66 ms).
    {
        AudioGraph g(kFs);
        g.setBypass(true);
        g.setTargetAzimuth(90.0f);
        const auto out = render(g, noise(n, 0.2f));
        const double expected = SpatialParams::forAzimuth(90.0f, kFs).delaySamples[0];
        CHECK_NEAR(expected, 31.5, 0.5);
        CHECK_NEAR(leftLagSamples(out, 1000, n - 100), expected, 1.5);
    }

    // 2. Espelho (-90°): agora é a direita que atrasa.
    {
        AudioGraph g(kFs);
        g.setBypass(true);
        g.setTargetAzimuth(-90.0f);
        const auto out = render(g, noise(n, 0.2f));
        CHECK(leftLagSamples(out, 1000, n - 100) < -29.0);
    }

    // 3. Sombra da cabeça: grande nos agudos, pequena nos graves; bate com o modelo analítico.
    {
        const SpatialParams p = SpatialParams::forAzimuth(90.0f, kFs);
        for (double f : {250.0, 4000.0}) {
            AudioGraph g(kFs);
            g.setBypass(true);
            g.setTargetAzimuth(90.0f);
            const auto out = render(g, sine(f, n, 0.1f));
            const double measured = rmsDb(out, 1, 4800, n) - rmsDb(out, 0, 4800, n); // direita - esquerda
            const double model = p.shadowGainDb(1, f, kFs) - p.shadowGainDb(0, f, kFs);
            CHECK_NEAR(measured, model, 1.0);
            if (f == 4000.0) CHECK(measured > 10.0);
            if (f == 250.0) CHECK(measured < 3.0);
        }
    }

    // 4. À frente (0°): as duas orelhas recebem o mesmo sinal.
    {
        AudioGraph g(kFs);
        g.setBypass(true);
        g.setTargetAzimuth(0.0f);
        const auto out = render(g, noise(4800, 0.2f));
        double maxDiff = 0.0;
        for (int i = 0; i < 4800; i++) maxDiff = std::max(maxDiff, (double)std::fabs(out[2 * i] - out[2 * i + 1]));
        CHECK(maxDiff < 1e-6);
    }

    // 5. Sem direção: identidade (os outros treinos e o teste auditivo não são afetados).
    {
        AudioGraph g(kFs);
        g.setBypass(true);
        g.setTargetAzimuth(60.0f);
        g.disableTargetSpatial();
        const auto in = noise(4800, 0.2f);
        const auto out = render(g, in);
        double maxError = 0.0;
        for (int i = 0; i < 4800; i++) maxError = std::max(maxError, (double)std::fabs(out[2 * i] - in[i]));
        CHECK(maxError < 1e-6);
    }

    // 6. O ruído (masker) também pode vir de um lado: ruído à esquerda, orelha direita atrasada.
    {
        AudioGraph g(kFs);
        const auto masker = noise(n, 0.1f);
        g.setMasker(masker.data(), (int)masker.size(), 1.0f, true);
        g.setMaskerAzimuth(-60.0f);
        std::vector<float> out(2 * n);
        g.render(out.data(), n);
        CHECK(leftLagSamples(out, 1000, n - 100) < -15.0);
    }

    return checkSummary("spatial_test");
}
