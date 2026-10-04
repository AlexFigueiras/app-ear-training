#include "dsp_engine.h"
#include <cmath>
#include <algorithm>
#include <chrono>

inline float processSoftKneeLimiter(float sample, DspEngine* engine) {
    const float threshold = 0.707f; // -3 dBFS (Volume máximo linear de fala)
    const float maxLimit = 0.98f;   // -0.17 dBFS (Trava Absoluta)
    const float headroom = maxLimit - threshold;

    float absSample = std::abs(sample);
    if (absSample <= threshold) {
        return sample; 
    } 
    
    // Modo Engenheiro: Captura o pico de saturação para a UI
    engine->setSoftKneeFlag();

    // Região Saturada Asintótica
    float overShoot = absSample - threshold;
    float outSample = threshold + (overShoot / (1.0f + (overShoot / headroom)));
    
    return (sample > 0.0f) ? outSample : -outSample;
}

DspEngine::DspEngine(float sr) : sampleRate(sr) {
    for (int i = 0; i < 2; i++) {
        for(int j=0; j<kMaxFramesPerCallback; j++) {
            channelDataBuffer[i][j] = 0.0f;
            highFreqBuffer[i][j] = 0.0f;
        }
        delayWritePtr[i] = 0;
        for(int j=0; j<kDelayBufferSize; j++) lowFreqDelayBuffer[i][j] = 0.0f;
    }
    initializeParameters();
}

DspEngine::~DspEngine() {}

// Configura matematicamente o Motor de Acordo com as Regras Clínicas
void DspEngine::initializeParameters() {
    for (int i = 0; i < 2; i++) {
        // 1. Crossover de 1000 Hz: Filtro Passa-Baixa (IIR) para os graves (Q = 0.707 - Butterworth)
        lowPass1000Hz[i].configureLowPass(sampleRate, 1000.0f, 0.707f);

        // 2. Filtro FIR Janelado (Fase Estritamente Linear) - 512 taps, Beta 5.0 (Kaiser)
        highPassFir[i].designHighPassKaiser(sampleRate, 1000.0f, 5.0f);

        // 3. TEE: Temporal Envelope Expansion
        teeProcessor[i].initialize(sampleRate, 5.0f, 45.0f, 0.7f);

        // 4. Equalizador de Pico (Peaking EQ): Realça Transientes
        peakingEQ[i].configurePeakingEQ(sampleRate, 5500.0f, 4.32f, 4.0f);
    }
}

// Reconfigura Peaking EQ com o perfil audiométrico do paciente
// Aplica a frequência de maior perda e seu Half-Gain como novo ponto central do EQ
void DspEngine::setAudiogramProfile(const float* freqs, const float* gains, int count) {
    if (count <= 0) return;

    // Encontra a frequência com maior ganho (maior perda no audiograma = maior ganho compensatório)
    float maxGain = gains[0];
    float centerFreq = freqs[0];
    for (int i = 1; i < count; i++) {
        if (gains[i] > maxGain) {
            maxGain = gains[i];
            centerFreq = freqs[i];
        }
    }

    // Reconfigura Peaking EQ para a frequência de maior déficit
    // Q=4.32 preserva banda estreita (~0.23 oitava) para precisão clínica
    const float Q = 4.32f;
    for (int i = 0; i < 2; i++) {
        peakingEQ[i].configurePeakingEQ(sampleRate, centerFreq, Q, maxGain);
    }
}

// Núcleo de Latência Ultrabaixa (Obrigação: Executar em < 20ms de latência overall)
void DspEngine::processAudioBlock(float* audioData, int numFrames, int numChannels) {
    if (numChannels > 2) numChannels = 2; // Suporta apenas mono/stereo
    // Blocos maiores que o buffer interno são processados em pedaços (antes o excedente saía
    // sem processamento).
    for (int offset = 0; offset < numFrames; offset += kMaxFramesPerCallback) {
        const int frames = std::min(kMaxFramesPerCallback, numFrames - offset);
        processChunk(audioData + offset * numChannels, frames, numChannels);
    }
}

void DspEngine::processChunk(float* audioData, int numFrames, int numChannels) {
    if (numChannels > 2) numChannels = 2; // Suporta apenas mono/stereo


    // 1. Extrai canais para processamento FIR (usando buffer pré-alocado)
    for (int ch = 0; ch < numChannels; ch++) {
        for (int i = 0; i < numFrames; i++) {
            channelDataBuffer[ch][i] = audioData[i * numChannels + ch];
        }
        
        // 2. Processa FIR High-Pass
        highPassFir[ch].processBlockOverlapSave(channelDataBuffer[ch], highFreqBuffer[ch], numFrames);
    }

    // 3. Loop de Processamento Final (Interleaved)
    for (int i = 0; i < numFrames; i++) {
        for (int ch = 0; ch < numChannels; ch++) {
            float sample = channelDataBuffer[ch][i];

            // A. Grave via IIR + Retardo para alinhar com o Agudo
            float lowFreqRaw = lowPass1000Hz[ch].process(sample);
            
            // Pega amostra antiga (atrasada)
            int readPtr = (delayWritePtr[ch] - kFirGroupDelay + kDelayBufferSize) % kDelayBufferSize;
            float lowFreq = lowFreqDelayBuffer[ch][readPtr];
            
            // Salva amostra atual no buffer circular
            lowFreqDelayBuffer[ch][delayWritePtr[ch]] = lowFreqRaw;
            delayWritePtr[ch] = (delayWritePtr[ch] + 1) % 512;

            // B. Agudo via FIR (já calculado com atraso natural de 256)
            float highFreq = highFreqBuffer[ch][i]; 
            
            // C. Modulação TEE
            highFreq = teeProcessor[ch].process(highFreq);

            // D. Peaking EQ
            highFreq = peakingEQ[ch].process(highFreq);

            // E. Mix e Conditional Soft-Knee Limiter (Saturação Transparente)
            float outSample = lowFreq + highFreq;
            outSample = processSoftKneeLimiter(outSample, this);

            audioData[i * numChannels + ch] = outSample;
        }
    }
}
