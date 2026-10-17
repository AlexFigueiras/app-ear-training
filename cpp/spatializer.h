#pragma once
#include <algorithm>
#include <cmath>
#include "handoff.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Parâmetros de uma direção (calculados fora da thread de áudio).
//
// - ITD (diferença de tempo entre orelhas): fórmula de Woodworth, (a/c)(θ + sen θ), com cabeça de
//   raio 8,75 cm; ~0,66 ms (≈31 amostras a 48 kHz) a 90°.
// - Sombra da cabeça: modelo de Brown & Duda (1998), filtro de 1ª ordem por orelha. A orelha do
//   lado da fonte ganha agudos e a do lado oposto perde, como numa cabeça real (a diferença de
//   nível é grande nos agudos e quase nula nos graves).
//
// Substitui o "pan ±1" do Espacial antigo, que tocava a palavra num ouvido só.
struct SpatialParams {
    // [0] = esquerda, [1] = direita
    float delaySamples[2] = {0.0f, 0.0f};
    float b0[2] = {1.0f, 1.0f}, b1[2] = {0.0f, 0.0f}, a1[2] = {0.0f, 0.0f};

    static constexpr double kHeadRadius = 0.0875; // m
    static constexpr double kSpeedOfSound = 343.0; // m/s

    // azimute em graus: 0 = frente, +90 = direita, -90 = esquerda.
    static SpatialParams forAzimuth(float azimuthDeg, float sampleRate) {
        SpatialParams p;
        const double az = std::clamp((double)azimuthDeg, -90.0, 90.0) * M_PI / 180.0;
        const double itdSeconds = kHeadRadius / kSpeedOfSound * (std::fabs(az) + std::sin(std::fabs(az)));
        const int far = az >= 0 ? 0 : 1; // fonte à direita: a esquerda é a orelha distante
        p.delaySamples[far] = (float)(itdSeconds * sampleRate);

        // Ângulo entre a fonte e cada orelha (orelhas em -90° e +90°).
        const double towardEar[2] = {std::fabs(az * 180.0 / M_PI + 90.0), std::fabs(az * 180.0 / M_PI - 90.0)};
        const double w0 = kSpeedOfSound / kHeadRadius;
        const double tauK = 2.0 * sampleRate / (2.0 * w0); // bilinear: s = 2·fs·(1-z^-1)/(1+z^-1)
        for (int ear = 0; ear < 2; ear++) {
            const double alpha = 1.05 + 0.95 * std::cos(towardEar[ear] / 150.0 * M_PI);
            const double norm = 1.0 + tauK;
            p.b0[ear] = (float)((1.0 + alpha * tauK) / norm);
            p.b1[ear] = (float)((1.0 - alpha * tauK) / norm);
            p.a1[ear] = (float)((1.0 - tauK) / norm);
        }
        return p;
    }

    // Ganho analítico (dB) da sombra de uma orelha na frequência f (para testes).
    double shadowGainDb(int ear, double f, double sampleRate) const {
        const double w = 2.0 * M_PI * f / sampleRate;
        const double cr = std::cos(w), ci = -std::sin(w);
        const double nr = b0[ear] + b1[ear] * cr, ni = b1[ear] * ci;
        const double dr = 1.0 + a1[ear] * cr, di = a1[ear] * ci;
        return 10.0 * std::log10((nr * nr + ni * ni) / (dr * dr + di * di));
    }
};

// Aplica uma direção a um sinal estéreo na thread de áudio. Sem direção publicada = identidade.
class Spatializer {
public:
    static constexpr int kDelaySize = 64; // > 1,3 ms a 48 kHz

    explicit Spatializer(float sampleRate = 48000.0f) : sampleRate_(sampleRate) {}

    // --- Thread do Dart ---
    void setAzimuth(float azimuthDeg) {
        auto* p = new SpatialParams(SpatialParams::forAzimuth(azimuthDeg, sampleRate_));
        params_.publish(p);
    }
    // Sem direção: volta à identidade (publica parâmetros neutros).
    void disable() { params_.publish(new SpatialParams()); }

    // --- Thread de áudio ---
    inline void process(const SpatialParams* p, float& left, float& right) {
        float in[2] = {left, right};
        float out[2];
        for (int ear = 0; ear < 2; ear++) {
            delay_[ear][write_] = in[ear];
            out[ear] = readDelayed(ear, p->delaySamples[ear]);
            const float y = p->b0[ear] * out[ear] + p->b1[ear] * x1_[ear] - p->a1[ear] * y1_[ear];
            x1_[ear] = out[ear];
            y1_[ear] = y;
            out[ear] = y;
        }
        write_ = (write_ + 1) % kDelaySize;
        left = out[0];
        right = out[1];
    }

    // Chamado uma vez por bloco: adota parâmetros novos, se houver.
    const SpatialParams* acquire() { return params_.acquire(); }

private:
    // Atraso fracionário por interpolação linear (atraso até kDelaySize - 2 amostras).
    inline float readDelayed(int ear, float delay) const {
        const float d = std::clamp(delay, 0.0f, (float)(kDelaySize - 2));
        const int whole = (int)d;
        const float frac = d - (float)whole;
        const int i0 = (write_ - whole + kDelaySize) % kDelaySize;
        const int i1 = (i0 - 1 + kDelaySize) % kDelaySize;
        return delay_[ear][i0] * (1.0f - frac) + delay_[ear][i1] * frac;
    }

    float sampleRate_;
    Handoff<SpatialParams> params_;
    float delay_[2][kDelaySize] = {};
    int write_ = 0;
    float x1_[2] = {0.0f, 0.0f}, y1_[2] = {0.0f, 0.0f};
};
