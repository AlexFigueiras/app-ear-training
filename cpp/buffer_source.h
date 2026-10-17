#pragma once
#include <algorithm>
#include <atomic>
#include <cmath>
#include <vector>
#include "handoff.h"

// Um som pronto (palavra, tom, ruído) entregue pelo Dart. Mono ou estéreo intercalado.
struct AudioBuffer {
    std::vector<float> samples;
    int frames = 0;
    int channels = 1;
    float gain = 1.0f;
    bool loop = false;
};

// Toca um AudioBuffer na thread de áudio. A troca de buffer usa Handoff (sem lock, sem alocação
// na thread de áudio). Loop real com emenda contínua; parada com fade curto (sem clique).
class BufferSource {
public:
    static constexpr int kFadeFrames = 240; // 5 ms a 48 kHz

    // --- Thread do Dart ---

    void set(const float* data, int frames, int channels, float gain, bool loop) {
        if (data == nullptr || frames <= 0 || (channels != 1 && channels != 2)) {
            stop();
            return;
        }
        auto* buffer = new AudioBuffer();
        buffer->samples.assign(data, data + (size_t)frames * channels);
        buffer->frames = frames;
        buffer->channels = channels;
        buffer->gain = gain;
        buffer->loop = loop;
        stopRequested_.store(false, std::memory_order_release);
        handoff_.publish(buffer);
        framesRemaining_.store(frames, std::memory_order_release);
    }

    void stop() {
        handoff_.clearPending();
        stopRequested_.store(true, std::memory_order_release);
    }

    // Ganho extra em linear (ex.: nível do ruído), suavizado na thread de áudio.
    void setGain(float linear) { gainTarget_.store(linear, std::memory_order_release); }

    int framesRemaining() const { return framesRemaining_.load(std::memory_order_acquire); }

    // --- Thread de áudio ---

    // Preenche left/right com até `frames` amostras (zera o que faltar). Devolve true se tocou algo.
    bool read(float* left, float* right, int frames) {
        if (stopRequested_.exchange(false, std::memory_order_acq_rel) && handoff_.active() != nullptr) {
            fadeRemaining_ = kFadeFrames;
        }
        AudioBuffer* previous = handoff_.active();
        AudioBuffer* buffer = handoff_.acquire();
        if (buffer != previous) {
            position_ = 0;
            fadeRemaining_ = -1; // som novo toca inteiro
        }

        const float target = gainTarget_.load(std::memory_order_acquire);
        bool produced = false;
        for (int i = 0; i < frames; i++) {
            gainCurrent_ += (target - gainCurrent_) * 0.002f; // ~10 ms de suavização
            float l = 0.0f, r = 0.0f;
            if (buffer != nullptr && position_ < buffer->frames) {
                const float g = buffer->gain * gainCurrent_ * fadeGain();
                if (buffer->channels == 1) {
                    l = r = buffer->samples[position_] * g;
                } else {
                    l = buffer->samples[2 * position_] * g;
                    r = buffer->samples[2 * position_ + 1] * g;
                }
                produced = true;
                position_++;
                if (position_ >= buffer->frames && buffer->loop) position_ = 0;
                if (fadeRemaining_ == 0) position_ = buffer->frames; // fade terminou
            }
            left[i] = l;
            right[i] = r;
        }

        if (buffer != nullptr && position_ >= buffer->frames) {
            handoff_.releaseActive();
            fadeRemaining_ = -1;
            framesRemaining_.store(0, std::memory_order_release);
        } else if (buffer != nullptr) {
            framesRemaining_.store(buffer->loop ? buffer->frames : buffer->frames - position_,
                                   std::memory_order_release);
        }
        return produced;
    }

private:
    // Ganho do fade de parada (1 enquanto não há parada pedida).
    float fadeGain() {
        if (fadeRemaining_ < 0) return 1.0f;
        if (fadeRemaining_ == 0) return 0.0f;
        const float g = (float)fadeRemaining_ / kFadeFrames;
        fadeRemaining_--;
        return g;
    }

    Handoff<AudioBuffer> handoff_;
    std::atomic<bool> stopRequested_{false};
    std::atomic<float> gainTarget_{1.0f};
    std::atomic<int> framesRemaining_{0};

    // Estado só da thread de áudio.
    int position_ = 0;
    int fadeRemaining_ = -1; // -1 = sem fade; >0 = fade em curso; 0 = terminou
    float gainCurrent_ = 1.0f;
};
