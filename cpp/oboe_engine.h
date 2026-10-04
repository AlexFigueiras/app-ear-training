#pragma once
#include <oboe/Oboe.h>
#include <atomic>
#include <memory>
#include "audio_graph.h"

// Saída de áudio Android (Oboe/AAudio). Toda a mixagem e o processamento ficam no AudioGraph;
// aqui só há o stream, o callback e a telemetria de hardware.
class OboeEngine : public oboe::AudioStreamCallback {
public:
    OboeEngine();
    ~OboeEngine();

    bool start();
    void stop();

    AudioGraph& graph() { return graph_; }

    bool isDeviceDisconnected() const { return deviceDisconnected_.load(std::memory_order_acquire); }
    float getDspLoad() const { return dspUsage_.load(std::memory_order_relaxed); }

    double getLatencyMs() {
        if (outputStream_) {
            auto result = outputStream_->calculateLatencyMillis();
            return (bool)result ? result.value() : 0.0;
        }
        return 0.0;
    }

    int32_t getXRunCount() {
        if (outputStream_) {
            auto result = outputStream_->getXRunCount();
            return (bool)result ? result.value() : 0;
        }
        return 0;
    }

    // Callback de tempo real: só chama graph_.render (sem log, sem alocação, sem lock).
    oboe::DataCallbackResult onAudioReady(oboe::AudioStream* stream, void* audioData,
                                          int32_t numFrames) override;

    void onErrorBeforeClose(oboe::AudioStream* stream, oboe::Result error) override;
    // O Oboe chama este método numa thread própria (não a de áudio): reabrir o stream aqui é o
    // padrão documentado.
    void onErrorAfterClose(oboe::AudioStream* stream, oboe::Result error) override;

private:
    std::shared_ptr<oboe::AudioStream> outputStream_;
    AudioGraph graph_{48000.0f};
    std::atomic<bool> deviceDisconnected_{false};
    std::atomic<float> dspUsage_{0.0f};
};
