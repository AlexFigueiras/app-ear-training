#pragma once
#include <oboe/Oboe.h>
#include "sine_oscillator.h"
#include "sample_player.h"
#include "noise_generator.h"
#include <memory>
#include <chrono>
#include "dsp_engine.h"

class OboeEngine : public oboe::AudioStreamCallback {
private:
    std::shared_ptr<oboe::AudioStream> outputStream;
    std::shared_ptr<oboe::AudioStream> inputStream;
    
    DspEngine dspEngine;
    
    // Motor de Geração Clínica
    SineOscillator testOscillator;
    SamplePlayer targetPlayer;
    SamplePlayer noisePlayer;
    NoiseGenerator whiteNoiseGenerator;

    float sampleRate = 48000.0f; 
    std::atomic<float> targetPanning{0.0f}; // -1.0L, 0.0C, 1.0R

    // Event Tagging: Timestamp de hardware em nanosegundos para medir latência clínica
    std::atomic<int64_t> stimulusOnsetTimestampNs{0};
    
    // Resiliência: Flag de desconexão de fone
    std::atomic<bool> deviceDisconnected{false};
    
    // Telemetria Alpha 2 (Modo Engenheiro)
    std::atomic<float> dspUsage{0.0f};
    int32_t lastXRunCount = 0;
    
    bool wasStimulusActive = false;

public:
    OboeEngine();
    ~OboeEngine();

    bool start();
    void stop();

    // Controle Clínico
    void setTestTone(float freq, float amp, bool left, bool right) {
        testOscillator.setFrequency(freq);
        testOscillator.setAmplitude(amp);
        testOscillator.setChannels(left, right);
    }

    void setTargetSample(const float* data, int len, float vol, bool loop) {
        targetPlayer.setData(data, len);
        targetPlayer.setVolume(vol);
        targetPlayer.setLoop(loop);
    }

    void setTargetPanning(float panning) {
        targetPanning.store(panning);
    }

    void setNoiseSample(const float* data, int len, float vol, bool loop) {
        noisePlayer.setData(data, len);
        noisePlayer.setVolume(vol);
        noisePlayer.setLoop(loop);
    }

    void setNoiseIntensity(float intensity) {
        whiteNoiseGenerator.setAmplitude(intensity);
    }

    // Silêncio total: alvo, ruído (amostra e gerador) e tom de teste. Chamado ao sair de cada
    // tela de treino, ao ir para segundo plano e ao desconectar o fone. Antes, o ruído do
    // Coquetel continuava tocando para sempre depois da sessão.
    void silenceAll() {
        targetPlayer.stop();
        noisePlayer.stop();
        whiteNoiseGenerator.setAmplitude(0.0f);
        testOscillator.setStop();
    }

    void setAudiogramProfile(const float* freqs, const float* gains, int count) {
        dspEngine.setAudiogramProfile(freqs, gains, count);
    }

    // PASSO 2: Event Tagging Clínico
    // Marca o instante exato em que o estímulo é escrito pelo hardware de áudio.
    void markStimulusOnset() {
        auto now = std::chrono::steady_clock::now();
        stimulusOnsetTimestampNs.store(
            std::chrono::duration_cast<std::chrono::nanoseconds>(now.time_since_epoch()).count(),
            std::memory_order_release
        );
    }

    int64_t getStimulusTimestampNs() const {
        return stimulusOnsetTimestampNs.load(std::memory_order_acquire);
    }
    
    bool isDeviceDisconnected() const {
        return deviceDisconnected.load(std::memory_order_acquire);
    }

    // Loop Nativo assíncrono do Hardware (Callback)
    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream *oboeStream,
        void *audioData,
        int32_t numFrames) override;

    void onErrorBeforeClose(oboe::AudioStream *oboeStream, oboe::Result error) override;
    void onErrorAfterClose(oboe::AudioStream *oboeStream, oboe::Result error) override;

    double getLatencyMs() {
        if (outputStream) {
            auto result = outputStream->calculateLatencyMillis();
            return (bool)result ? result.value() : 0.0;
        }
        return 0.0;
    }

    int32_t getXRunCount() {
        if (outputStream) {
            auto result = outputStream->getXRunCount();
            return (bool)result ? result.value() : 0;
        }
        return 0;
    }

    float getDspLoad() {
        return dspUsage.load(std::memory_order_relaxed);
    }
    
    DspEngine& getDspEngine() { return dspEngine; }
};
