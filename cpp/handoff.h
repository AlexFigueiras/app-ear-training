#pragma once
#include <atomic>

// Troca de objetos entre a thread do Dart (produtora única) e a thread de áudio (consumidora).
//
// Regra de tempo real: a thread de áudio nunca aloca nem libera memória. O Dart aloca o objeto
// novo e o publica; a thread de áudio só troca ponteiros atômicos e "aposenta" o objeto antigo
// numa vaga; o Dart libera os aposentados na próxima chamada. Substitui o anel SPSC antigo, em
// que o Dart chamava clear() enquanto a thread de áudio lia (corrida de dados).
template <typename T, int kRetireSlots = 8>
class Handoff {
public:
    Handoff() {
        for (auto& slot : retired_) slot.store(nullptr, std::memory_order_relaxed);
    }

    ~Handoff() {
        delete pending_.exchange(nullptr);
        delete active_;
        collect();
    }

    Handoff(const Handoff&) = delete;
    Handoff& operator=(const Handoff&) = delete;

    // --- Thread do Dart ---

    // Publica um objeto novo (posse transferida). Um pendente ainda não adotado é descartado.
    void publish(T* next) {
        collect();
        delete pending_.exchange(next, std::memory_order_acq_rel);
    }

    // Descarta o pendente (se houver) sem publicar outro.
    void clearPending() {
        collect();
        delete pending_.exchange(nullptr, std::memory_order_acq_rel);
    }

    // Libera os objetos aposentados pela thread de áudio.
    void collect() {
        for (auto& slot : retired_) delete slot.exchange(nullptr, std::memory_order_acq_rel);
    }

    // --- Thread de áudio ---

    // Adota o pendente, se houver vaga para aposentar o atual. Devolve o ativo (ou nullptr).
    T* acquire() {
        if (pending_.load(std::memory_order_acquire) != nullptr) {
            if (active_ == nullptr || retire(active_)) {
                active_ = pending_.exchange(nullptr, std::memory_order_acq_rel);
            }
        }
        return active_;
    }

    // Aposenta o ativo (fim de um som sem loop, ou silêncio pedido).
    void releaseActive() {
        if (active_ != nullptr && retire(active_)) active_ = nullptr;
    }

    T* active() const { return active_; }

private:
    bool retire(T* object) {
        for (auto& slot : retired_) {
            T* expected = nullptr;
            if (slot.compare_exchange_strong(expected, object, std::memory_order_acq_rel)) return true;
        }
        return false; // sem vaga: tenta de novo no próximo bloco
    }

    std::atomic<T*> pending_{nullptr};
    T* active_ = nullptr; // só a thread de áudio lê e escreve
    std::atomic<T*> retired_[kRetireSlots];
};
