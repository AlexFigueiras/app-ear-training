#pragma once
// Mini-framework de teste para o job `native-tests` do CI (g++ no host, sem dependências).
// Cada *_test.cpp é um executável: retorna 0 se todos os CHECKs passaram.
#include <cmath>
#include <cstdio>

inline int& checkFailures() {
    static int failures = 0;
    return failures;
}

#define CHECK(cond)                                                              \
    do {                                                                         \
        if (!(cond)) {                                                           \
            std::printf("FALHOU %s:%d: %s\n", __FILE__, __LINE__, #cond);        \
            checkFailures()++;                                                   \
        }                                                                        \
    } while (0)

#define CHECK_NEAR(actual, expected, tol)                                        \
    do {                                                                         \
        const double a_ = (actual), e_ = (expected);                             \
        if (std::fabs(a_ - e_) > (tol)) {                                        \
            std::printf("FALHOU %s:%d: %s = %.4f, esperado %.4f (±%.4f)\n",      \
                        __FILE__, __LINE__, #actual, a_, e_, (double)(tol));     \
            checkFailures()++;                                                   \
        }                                                                        \
    } while (0)

inline int checkSummary(const char* suite) {
    if (checkFailures() == 0) {
        std::printf("OK %s\n", suite);
        return 0;
    }
    std::printf("%s: %d falha(s)\n", suite, checkFailures());
    return 1;
}
