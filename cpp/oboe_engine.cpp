#include "oboe_engine.h"
#include <chrono>
#include <iostream>

#if defined(__x86_64__) || defined(__i386__)
#include <xmmintrin.h>
#include <pmmintrin.h>
#endif

namespace {
    inline void setDenormalsAreZero() {
#if defined(__aarch64__)
        uint64_t fpcr;
        __asm__ __volatile__("mrs %0, fpcr" : "=r"(fpcr));
        fpcr |= (1 << 24); // FZ (Flush-To-Zero)
        __asm__ __volatile__("msr fpcr, %0" : : "r"(fpcr));
#elif defined(__arm__)
        uint32_t fpscr;
        __asm__ __volatile__("vmrs %0, fpscr" : "=r"(fpscr));
        fpscr |= (1 << 24); // FZ
        __asm__ __volatile__("vmsr fpscr, %0" : : "r"(fpscr));
#elif defined(__x86_64__) || defined(__i386__)
        _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
        _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);
#endif
    }
}

OboeEngine::OboeEngine() = default;

OboeEngine::~OboeEngine() {
    stop();
}

bool OboeEngine::start() {
    if (outputStream_) return true; // idempotente

    oboe::AudioStreamBuilder builder;
    builder.setSampleRate(48000);
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    builder.setFormat(oboe::AudioFormat::Float);
    builder.setChannelCount(oboe::ChannelCount::Stereo);
    builder.setDirection(oboe::Direction::Output);
    builder.setCallback(this);

    oboe::Result result = builder.openStream(outputStream_);
    if (result == oboe::Result::OK) {
        outputStream_->setBufferSizeInFrames(outputStream_->getFramesPerBurst() * 2);
        deviceDisconnected_.store(false, std::memory_order_release);
        result = outputStream_->requestStart();
        if (result == oboe::Result::OK) return true;
    }
    return false;
}

void OboeEngine::stop() {
    if (outputStream_) {
        outputStream_->requestStop();
        outputStream_->close();
        outputStream_.reset();
    }
}

oboe::DataCallbackResult OboeEngine::onAudioReady(oboe::AudioStream* stream, void* audioData,
                                                  int32_t numFrames) {
    const auto startTime = std::chrono::steady_clock::now();
    setDenormalsAreZero();

    float* out = static_cast<float*>(audioData);
    if (stream->getChannelCount() == 2) {
        graph_.render(out, numFrames);
    } else {
        // Saída mono (raro): o grafo é sempre estéreo; não há como mixar sem buffer extra,
        // então entregamos silêncio em vez de áudio errado.
        std::fill(out, out + numFrames * stream->getChannelCount(), 0.0f);
    }

    const auto elapsedNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                               std::chrono::steady_clock::now() - startTime)
                               .count();
    const double availableNs = (double)numFrames / 48000.0 * 1e9;
    dspUsage_.store((float)(elapsedNs / availableNs), std::memory_order_relaxed);
    return oboe::DataCallbackResult::Continue;
}

void OboeEngine::onErrorBeforeClose(oboe::AudioStream*, oboe::Result error) {
    std::cerr << "Oboe onErrorBeforeClose: " << oboe::convertToText(error) << std::endl;
    deviceDisconnected_.store(true, std::memory_order_release);
}

void OboeEngine::onErrorAfterClose(oboe::AudioStream*, oboe::Result) {
    // Ex.: fim de chamada telefônica ou troca de dispositivo. O stream antigo já foi fechado.
    outputStream_.reset();
    start();
}
