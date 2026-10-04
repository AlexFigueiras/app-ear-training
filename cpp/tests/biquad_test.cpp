// Resposta em frequência dos biquads de cpp/biquad_filter.h: medida com senoides e comparada
// com a resposta analítica (magnitudeDb), que o projeto do EQ usa.
#include "biquad_filter.h"
#include "check.h"

static constexpr float kFs = 48000.0f;

// Ganho em dB para uma senoide, depois de descartar o transiente inicial.
static double measuredGainDb(const BiquadCoeffs& c, double freqHz) {
    BiquadState state;
    const int settle = 4800, measure = 48000;
    double inEnergy = 0.0, outEnergy = 0.0;
    for (int n = 0; n < settle + measure; n++) {
        const float x = (float)std::sin(2.0 * M_PI * freqHz * n / kFs);
        const float y = state.process(c, x);
        if (n >= settle) {
            inEnergy += (double)x * x;
            outEnergy += (double)y * y;
        }
    }
    return 10.0 * std::log10(outEnergy / inEnergy);
}

int main() {
    const BiquadCoeffs peak = BiquadCoeffs::peaking(kFs, 4000.0f, 1.0f, 6.0f);
    CHECK_NEAR(measuredGainDb(peak, 4000.0), 6.0, 0.3);
    CHECK_NEAR(measuredGainDb(peak, 250.0), 0.0, 0.5);
    CHECK_NEAR(peak.magnitudeDb(4000.0, kFs), measuredGainDb(peak, 4000.0), 0.1);
    CHECK_NEAR(peak.magnitudeDb(1500.0, kFs), measuredGainDb(peak, 1500.0), 0.1);

    const BiquadCoeffs cut = BiquadCoeffs::peaking(kFs, 2000.0f, 1.0f, -6.0f);
    CHECK_NEAR(measuredGainDb(cut, 2000.0), -6.0, 0.3);

    // Ganho 0 dB = identidade exata (o EQ "plano" não pode colorir o som).
    const BiquadCoeffs flat = BiquadCoeffs::peaking(kFs, 3000.0f, 2.0f, 0.0f);
    CHECK_NEAR(flat.b0, 1.0, 1e-6);
    CHECK_NEAR(flat.b1, flat.a1, 1e-6);
    CHECK_NEAR(flat.b2, flat.a2, 1e-6);

    const BiquadCoeffs lowPass = BiquadCoeffs::lowPass(kFs, 1000.0f, 0.707f);
    CHECK_NEAR(measuredGainDb(lowPass, 100.0), 0.0, 0.2);
    CHECK_NEAR(measuredGainDb(lowPass, 1000.0), -3.0, 0.3);
    CHECK(measuredGainDb(lowPass, 8000.0) < -30.0);

    return checkSummary("biquad_test");
}
