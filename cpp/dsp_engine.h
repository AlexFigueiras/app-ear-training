#pragma once
#include "biquad_filter.h"
#include "fir_filter.h"
#include "tee_processor.h"
#include <vector>

// Motor de Processamento Digital de Sinais do Inova Simples Hearing
class DspEngine {
private:
    float sampleRate;

    // Componentes Acústicos (Stereo ready - Dual path)
    BiquadFilter lowPass1000Hz[2];  // Crossover para graves (L/R)
    BiquadFilter peakingEQ[2];      // Reforço paramétrico para fonemas /s/ (L/R)
    
    // Novo Pipeline Clínico de Compressão e Transientes (> 1.000 Hz)
    PartitionedFIR highPassFir[2];
    TemporalEnvelopeExpander teeProcessor[2];

    static constexpr int kMaxFramesPerCallback = 1024;
    static constexpr int kDelayBufferSize = 512;
    static constexpr int kFirGroupDelay = kDelayBufferSize / 2; // 256 amostras de atraso para FIR de 512 taps

    // Novo: Delay de compensação para alinhar IIR (Grave) com o FIR (Agudo)
    float lowFreqDelayBuffer[2][kDelayBufferSize]; 
    int delayWritePtr[2];

    // Buffers estáticos para alocação zero no hot path
    float channelDataBuffer[2][kMaxFramesPerCallback];
    float highFreqBuffer[2][kMaxFramesPerCallback];

    void processChunk(float* audioData, int numFrames, int numChannels);

    // Modo Engenheiro: Diagnóstico de Saturação
    std::atomic<bool> isSoftKneeHit{false};

public:
    DspEngine(float sr = 48000.0f);
    ~DspEngine();

    void initializeParameters();

    // Reconfigura o Peaking EQ com base no audiograma do paciente (Half-Gain Rule)
    // freqs: array de frequências (Hz), gains: array de ganhos (dB), count: tamanho
    void setAudiogramProfile(const float* freqs, const float* gains, int count);

    // Bloco Principal de Processamento do Callback de Áudio (C++ Core)
    void processAudioBlock(float* audioData, int numFrames, int numChannels);

    bool consumeSoftKneeFlag() {
        return isSoftKneeHit.exchange(false, std::memory_order_relaxed);
    }
    
    void setSoftKneeFlag() {
        isSoftKneeHit.store(true, std::memory_order_relaxed);
    }
};
