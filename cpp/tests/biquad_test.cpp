// Resposta em frequência dos biquads de cpp/biquad_filter.h, medida com senoides.
#include "biquad_filter.h"
#include "check.h"

static constexpr float kFs = 48000.0f;

// Ganho em dB de um filtro para uma senoide, depois de descartar o transiente inicial.
static double gainDb(BiquadFilter filter, double freqHz) {
    const int settle = 4800, measure = 48000;
    double inEnergy = 0.0, outEnergy = 0.0;
    for (int n = 0; n < settle + measure; n++) {
        const float x = (float)std::sin(2.0 * M_PI * freqHz * n / kFs);
        const float y = filter.process(x);
        if (n >= settle) {
            inEnergy += (double)x * x;
            outEnergy += (double)y * y;
        }
    }
    return 10.0 * std::log10(outEnergy / inEnergy);
}

int main() {
    BiquadFilter peak;
    peak.configurePeakingEQ(kFs, 4000.0f, 1.0f, 6.0f);
    CHECK_NEAR(gainDb(peak, 4000.0), 6.0, 0.3);
    CHECK_NEAR(gainDb(peak, 250.0), 0.0, 0.5);

    BiquadFilter cut;
    cut.configurePeakingEQ(kFs, 2000.0f, 1.0f, -6.0f);
    CHECK_NEAR(gainDb(cut, 2000.0), -6.0, 0.3);

    BiquadFilter lowPass;
    lowPass.configureLowPass(kFs, 1000.0f, 0.707f);
    CHECK_NEAR(gainDb(lowPass, 100.0), 0.0, 0.2);
    CHECK_NEAR(gainDb(lowPass, 1000.0), -3.0, 0.3);
    CHECK(gainDb(lowPass, 8000.0) < -30.0);

    return checkSummary("biquad_test");
}
