cmake_minimum_required(VERSION 3.22.1)
project(dsp_audio_engine)

# Injeta a biblioteca do Google Oboe via FetchContent
include(FetchContent)
FetchContent_Declare(
    oboe
    GIT_REPOSITORY https://github.com/google/oboe.git
    GIT_TAG        1.8.1
)
FetchContent_MakeAvailable(oboe)

# Configuração C++17 para bibliotecas modernas
set(CMAKE_CXX_STANDARD 17)

# Adiciona a biblioteca compartilhada (JNI/FFI)
add_library(dsp_audio_engine SHARED
    native_bridge.cpp
    dsp_engine.cpp
    oboe_engine.cpp
    fir_filter.cpp
    pffft.c
)

# OTIMIZAÇÃO DE HARDWARE (ARM NEON & -O3) PARA PFFFT
# Ativando flags de vetorização SIMD mandatórias
if(${ANDROID_ABI} STREQUAL "armeabi-v7a")
    target_compile_options(dsp_audio_engine PRIVATE -O3 -mfpu=neon)
else()
    target_compile_options(dsp_audio_engine PRIVATE -O3)
endif()

# Google Play exige .so com segmentos ELF alinhados a 16 KB (Android 15+). O NDK r28+ já faz
# isso por padrão; o flag explícito mantém a garantia se o build cair num NDK mais antigo.
if(ANDROID)
    target_link_options(dsp_audio_engine PRIVATE
        "-Wl,-z,max-page-size=16384"
        "-Wl,-z,common-page-size=16384")
endif()

# Pesquisa pela biblioteca de log do Android
find_library(log-lib log)

# Vincula as bibliotecas necessárias para o Motor Biônico
target_link_libraries(dsp_audio_engine
    PRIVATE
    ${log-lib}
    android
    oboe
)
