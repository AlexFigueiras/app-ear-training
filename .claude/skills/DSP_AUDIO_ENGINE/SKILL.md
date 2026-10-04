---
name: dsp-audio-engine
description: "Motor de áudio nativo C++/Oboe (via Dart FFI) do BOSYN: reprodução de estímulos pré-gravados com EQ por orelha, mixagem de ruído com SNR exato e segurança de tempo real."
risk: hardware-critical-latency
source: inova-simples-hearing
date_added: "2026-03-25"
date_revised: "2026-10-04"
keywords: [oboe, dart-ffi, biquad-eq, real-time-safety, snr, safety-limiter, itd-ild]
---

# DSP Audio Engine (BOSYN)

> **Revisão de 2026-10-04 (plano "treino eficaz", `docs/DECISIONS.md`).** A versão anterior
> desta skill prescrevia três coisas que se mostraram erradas:
> - um crossover FIR de 1 kHz implementado sobre uma FFT placeholder, que estourava o buffer no
>   callback;
> - um único peaking EQ com Q = 4,32 na "pior" frequência;
> - um "TEE" com γ = 0,7, que é **compressão** e não expansão, aplicado a tudo, inclusive aos
>   tons do teste auditivo.
>
> Nada disso deve ser reintroduzido.

## 1. Princípio: todo estímulo é pré-gravado
O app não processa microfone ao vivo; só toca palavras de TTS, tons e ruídos já prontos. Por
isso:
- **latência de ida e volta não é requisito clínico**; o requisito é **tempo de início preciso**
  e **áudio sem falhas**;
- o motor C++/Oboe existe para tocar com segurança, mixar alvo + ruído e aplicar EQ por orelha;
- o que pode ser preparado antes (decodificar WAV, reamostrar, normalizar RMS, gerar babble) é
  feito em Dart, fora do callback, e testado com `flutter test`.

## 2. Arquitetura-alvo (Etapa 3 do plano)
```
Dart: TTS WAV -> wav_decoder (48 kHz) -> normaliza RMS -> FFI
C++:  BufferSource(alvo) -> EQ por orelha (biquads) -> [ITD/ILD] -+-> mix -> limitador -1 dBFS -> Oboe
      BufferSource(ruído/babble, loop) ---- ganho em dB ----------+
      Tons de teste/calibração: caminho com BYPASS (sem EQ), rampa de 20 ms
```
- **EQ multibanda de biquads** (`cpp/biquad_filter.h`):
  - bandas em 250, 500, 1k, 2k, 3k, 4k, 6k e 8k Hz (shelf nas pontas, peaking no meio);
  - **ganho por orelha**, sem média entre esquerda e direita;
  - ganho relativo à melhor frequência do paciente e com teto.
- **Boost de dificuldade** (`set_high_band_boost_db`): ganho extra só na banda aguda. Nunca
  ganho de banda larga com clamp.
- **O ruído entra depois do EQ.** Assim o SNR é exatamente o pedido: ruído em nível fixo e o
  alvo se move.
- **Bypass** obrigatório para tons de medição. Medir limiar através de processamento não
  linear invalida o audiograma.
- **Limitador de segurança** a −1 dBFS, com contador de acionamentos exposto ao painel de QA.
  Em uso normal, ele **não deveria agir**: o headroom vem da normalização em Dart.

## 3. Regras de tempo real (inegociáveis)
- No callback: **nada de alocação, `free`, mutex, I/O ou log** (`std::cerr`, `__android_log`).
- **Troca de buffer** entre a thread do Dart e a de áudio: ponteiros atômicos (pending/active/
  retired). A thread de áudio nunca chama `clear()` de um buffer que o Dart escreve.
- O restart depois de erro do Oboe (`onErrorAfterClose`) roda **fora** da thread de callback.
- O processamento aceita blocos de qualquer tamanho (laço em pedaços), sem descartar frames.
- `setDenormalsAreZero()` no início do callback.

## 4. Ponte FFI
- Os lookups de símbolos (`lookupFunction`) são feitos **uma vez** e guardados em campos
  `late final`, não a cada chamada.
- Todo símbolo chamado pelo Dart precisa existir em `cpp/native_bridge.cpp`. Símbolo ausente =
  crash na hora da chamada.
- Buffers enviados ao C++ são copiados para memória do motor. O Dart libera o seu lado logo
  depois.

## 5. Sinal e medida
- TTS do Google WaveNet sai a 24 kHz por padrão: **sempre** ler a taxa do cabeçalho WAV
  (percorrer os chunks RIFF, não assumir 44 bytes) e reamostrar para 48 kHz.
- Tons: rampa cosseno de 20 ms na entrada e na saída. Tom abrupto gera clique de banda larga e
  deixa "ouvir" 8 kHz pela energia grave.
- Sem calibração por fone (RETSPL), os níveis são **relativos** ("triagem relativa"), nunca
  "dB HL clínico".
- Espacialização = ITD (atraso fracionário, ~0–700 µs) + ILD em dB nas duas orelhas. Pan ±1
  (som num ouvido só) não treina localização.

## 6. Testes
- `cpp/tests/*_test.cpp` roda no CI (job `native-tests`, g++ com ASan/UBSan) com o
  mini-framework `cpp/tests/check.h`.
- Toda mudança de DSP precisa de teste de resposta medida, por exemplo ganho da banda ±1,5 dB,
  bypass = identidade, pico ≤ −1 dBFS e zero alocação no render.
- O que for Dart puro (decodificador, normalização, mixer de SNR) é testado com `flutter test`.
