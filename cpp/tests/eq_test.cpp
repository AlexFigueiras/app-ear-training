// EQ multibanda por orelha (cpp/eq_bank.h): o ganho medido em cada banda bate com o alvo.
#include "eq_bank.h"
#include "check.h"

static constexpr float kFs = 48000.0f;

static double measuredGainDb(const EqDesign& design, int ear, double freqHz) {
    EqState state;
    const int settle = 9600, measure = 48000;
    double inEnergy = 0.0, outEnergy = 0.0;
    for (int n = 0; n < settle + measure; n++) {
        const float x = (float)std::sin(2.0 * M_PI * freqHz * n / kFs) * 0.01f;
        const float y = state.process(design, ear, x);
        if (n >= settle) {
            inEnergy += (double)x * x;
            outEnergy += (double)y * y;
        }
    }
    return 10.0 * std::log10(outEnergy / inEnergy);
}

static void checkProfile(const float* left, const float* right, const char* name) {
    const EqDesign design = EqDesign::design(left, right, kFs);
    for (int b = 0; b < EqDesign::kBands; b++) {
        const double l = measuredGainDb(design, 0, EqDesign::kCenters[b]);
        const double r = measuredGainDb(design, 1, EqDesign::kCenters[b]);
        if (std::fabs(l - left[b]) > 1.5 || std::fabs(r - right[b]) > 1.5) {
            std::printf("  perfil %s, banda %.0f Hz: esq %.2f (alvo %.1f), dir %.2f (alvo %.1f)\n",
                        name, EqDesign::kCenters[b], l, left[b], r, right[b]);
        }
        CHECK_NEAR(l, left[b], 1.5);
        CHECK_NEAR(r, right[b], 1.5);
    }
}

int main() {
    // Plano: identidade (0 dB em tudo, inclusive entre as bandas).
    const float flat[EqDesign::kBands] = {0, 0, 0, 0, 0, 0, 0, 0};
    const EqDesign flatDesign = EqDesign::design(flat, flat, kFs);
    for (double f : {100.0, 700.0, 2500.0, 5000.0, 10000.0}) {
        CHECK_NEAR(flatDesign.responseDb(0, f, kFs), 0.0, 1e-4);
    }

    // Perda descendente típica (presbiacusia), orelhas assimétricas.
    const float sloping[EqDesign::kBands] = {0, 0, 2, 6, 10, 14, 18, 20};
    const float steeper[EqDesign::kBands] = {0, 2, 4, 10, 16, 22, 26, 28};
    checkProfile(sloping, steeper, "descendente");

    // Entalhe em 4 kHz (perda por ruído): vizinhos baixos, pico isolado.
    const float notch[EqDesign::kBands] = {0, 0, 0, 2, 8, 15, 8, 4};
    checkProfile(notch, notch, "entalhe 4k");

    // Só o boost de dificuldade nas bandas agudas (>= 3 kHz).
    const float boost[EqDesign::kBands] = {0, 0, 0, 0, 12, 12, 12, 12};
    checkProfile(boost, flat, "boost agudo");

    // Alvo acima do teto é limitado ao teto (não explode).
    const float huge[EqDesign::kBands] = {0, 0, 0, 0, 0, 0, 0, 90};
    const EqDesign capped = EqDesign::design(huge, flat, kFs);
    CHECK(capped.responseDb(0, 8000.0, kFs) <= EqDesign::kMaxGainDb + 1.5);

    return checkSummary("eq_test");
}
