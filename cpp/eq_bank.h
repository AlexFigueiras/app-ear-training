#pragma once
#include <algorithm>
#include "biquad_filter.h"

// EQ multibanda por orelha (substitui o crossover FIR de 1 kHz, o "TEE" e o peaking único).
//
// 8 bandas nas frequências do audiograma. Bandas vizinhas se sobrepõem, então o ganho pedido
// não é o ganho de cada filtro: o projeto ajusta os ganhos dos filtros por iteração até a
// resposta medida nas frequências centrais bater com o alvo (erro < 0,5 dB nos testes).
struct EqDesign {
    static constexpr int kBands = 8;
    static constexpr float kCenters[kBands] = {250.f, 500.f, 1000.f, 2000.f, 3000.f, 4000.f, 6000.f, 8000.f};
    // Q menor nas bandas espaçadas de uma oitava, maior nas espaçadas de meia oitava.
    static constexpr float kQ[kBands] = {1.4f, 1.4f, 1.4f, 1.4f, 2.0f, 2.0f, 2.0f, 1.6f};
    static constexpr float kMaxGainDb = 40.0f;

    BiquadCoeffs coeffs[2][kBands]; // [orelha esquerda/direita][banda]

    // Resposta total (dB) de uma orelha na frequência f.
    double responseDb(int ear, double f, double sampleRate) const {
        double total = 0.0;
        for (int b = 0; b < kBands; b++) total += coeffs[ear][b].magnitudeDb(f, sampleRate);
        return total;
    }

    // Projeta as duas orelhas. Fora da thread de áudio (custo: poucas centenas de µs).
    static EqDesign design(const float* leftDb, const float* rightDb, float sampleRate) {
        EqDesign d;
        const float* targets[2] = {leftDb, rightDb};
        for (int ear = 0; ear < 2; ear++) {
            double gain[kBands];
            double target[kBands];
            for (int b = 0; b < kBands; b++) {
                target[b] = std::clamp((double)targets[ear][b], 0.0, (double)kMaxGainDb);
                gain[b] = target[b];
            }
            for (int iteration = 0; iteration < 30; iteration++) {
                for (int b = 0; b < kBands; b++) {
                    d.coeffs[ear][b] = BiquadCoeffs::peaking(sampleRate, kCenters[b], kQ[b], (float)gain[b]);
                }
                for (int b = 0; b < kBands; b++) {
                    const double error = target[b] - d.responseDb(ear, kCenters[b], sampleRate);
                    gain[b] = std::clamp(gain[b] + 0.8 * error, -20.0, (double)kMaxGainDb + 20.0);
                }
            }
            for (int b = 0; b < kBands; b++) {
                d.coeffs[ear][b] = BiquadCoeffs::peaking(sampleRate, kCenters[b], kQ[b], (float)gain[b]);
            }
        }
        return d;
    }
};

// Estado dos filtros (só a thread de áudio usa).
struct EqState {
    BiquadState state[2][EqDesign::kBands];

    inline float process(const EqDesign& design, int ear, float x) {
        for (int b = 0; b < EqDesign::kBands; b++) x = state[ear][b].process(design.coeffs[ear][b], x);
        return x;
    }
};
