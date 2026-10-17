#pragma once
#include <cmath>
#include <complex>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Biquad (RBJ Audio EQ Cookbook) em Direct Form II Transposed.
// Coeficientes e estado ficam separados: o EQ troca de coeficientes entre threads (ver
// eq_bank.h) sem zerar o estado do filtro na thread de áudio.
struct BiquadCoeffs {
    float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f, a1 = 0.0f, a2 = 0.0f;

    // Equalizador de pico. Com dbGain = 0 os coeficientes são exatamente identidade.
    static BiquadCoeffs peaking(float sampleRate, float f0, float q, float dbGain) {
        const double A = std::pow(10.0, dbGain / 40.0);
        const double w0 = 2.0 * M_PI * f0 / sampleRate;
        const double alpha = std::sin(w0) / (2.0 * q);
        const double a0 = 1.0 + alpha / A;
        BiquadCoeffs c;
        c.b0 = (float)((1.0 + alpha * A) / a0);
        c.b1 = (float)((-2.0 * std::cos(w0)) / a0);
        c.b2 = (float)((1.0 - alpha * A) / a0);
        c.a1 = (float)((-2.0 * std::cos(w0)) / a0);
        c.a2 = (float)((1.0 - alpha / A) / a0);
        return c;
    }

    static BiquadCoeffs lowPass(float sampleRate, float f0, float q) {
        const double w0 = 2.0 * M_PI * f0 / sampleRate;
        const double alpha = std::sin(w0) / (2.0 * q);
        const double cw = std::cos(w0);
        const double a0 = 1.0 + alpha;
        BiquadCoeffs c;
        c.b0 = (float)(((1.0 - cw) / 2.0) / a0);
        c.b1 = (float)((1.0 - cw) / a0);
        c.b2 = (float)(((1.0 - cw) / 2.0) / a0);
        c.a1 = (float)((-2.0 * cw) / a0);
        c.a2 = (float)((1.0 - alpha) / a0);
        return c;
    }

    // Resposta em magnitude (dB) na frequência f, calculada analiticamente. Usada para projetar
    // o EQ (fora da thread de áudio).
    double magnitudeDb(double f, double sampleRate) const {
        const double w = 2.0 * M_PI * f / sampleRate;
        const std::complex<double> z1 = std::polar(1.0, -w);
        const std::complex<double> z2 = z1 * z1;
        const std::complex<double> num = (double)b0 + (double)b1 * z1 + (double)b2 * z2;
        const std::complex<double> den = 1.0 + (double)a1 * z1 + (double)a2 * z2;
        return 20.0 * std::log10(std::abs(num / den));
    }
};

struct BiquadState {
    float z1 = 0.0f, z2 = 0.0f;

    inline float process(const BiquadCoeffs& c, float x) {
        const float y = c.b0 * x + z1;
        z1 = c.b1 * x - c.a1 * y + z2;
        z2 = c.b2 * x - c.a2 * y;
        return y;
    }
};
