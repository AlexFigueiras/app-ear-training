---
name: dsp-audio-engine
description: "High-performance, low-latency C++/Dart audio engine for real-time neuro-acoustic rehabilitation."
risk: hardware-critical-latency
source: inova-simples-hearing
date_added: "2026-03-25"
keywords: [low-latency, oboe-exclusive, dart-ffi, iir-biquad, fir-hybrid, hrtf-convolution, envelope-expansion, zero-copy-memory]
---

# DSP Audio Engine (Low-Latency & Precision)

Esta skill prioriza a **performance bruta e a segurança de memória**, garantindo que o processamento sensorial seja transparente e livre de falhas (glitches).

> [!IMPORTANT]
> **MIGRAÇÃO CONCLUÍDA**: O motor `just_audio` foi totalmente removido do projeto.
> O motor oficial e exclusivo agora é o **Native C++ Audio Engine (Oboe/AAudio)** via Dart FFI. Toda a lógica de processamento clínico deve residir ou ser roteada através do `NativeDSPBridge`.


## 1. Mandato de Engenharia

Cada implementação de código deve satisfazer **todos os quatro requisitos**:

1. **Acesso Direto ao Hardware (Oboe/AAudio)**
   Uso obrigatório do modo `EXCLUSIVE` e buffers sintonizados no dobro do *burst size* nativo.

2. **Arquitetura Híbrida de Crossover**
   Divisão estrita em 1.000 Hz: IIR para economia de CPU (graves) e FIR para precisão de fase (agudos).

3. **Gerenciamento de Memória Zero-Copy**
   Uso de `Pointer.asTypedList` e `NativeFinalizer` para evitar qualquer latência de cópia ou vazamento de buffer.

4. **Fidelidade de Sharpening ($Q = 4.32$)**
   Aplicação de Peaking EQ cirúrgico em 1/3 de oitava para inteligibilidade vocal máxima.

❌ Sem processamento em threads de UI
❌ Sem alocação dinâmica dentro do Audio Callback
❌ Sem latência acima de 20ms
✅ Processamento determinístico, síncrono e de grau médico



## Manual Técnico de Engenharia de Processamento Digital de Sinais (DSP)
**Alvo:** Agente Antigravity (Codificação do Motor de Áudio)
**Objetivo:** Reabilitação Auditiva em Tempo Real e Aprimoramento de Sinal



### 1. Arquitetura de Filtros (FIR/IIR)
A base da personalização e equalização paramétrica do motor de áudio requer o uso híbrido de filtros de Resposta ao Impulso Finita (FIR) e Infinita (IIR).

*   **Filtros IIR (Biquads):** 
    Para equalização de múltiplas bandas e compensação de perdas auditivas específicas, os filtros Biquad (seções de segunda ordem) são fundamentais [1]. A função de transferência no domínio digital (Z) é definida como:
    $$H(z) = \frac{b_0 + b_1 z^{-1} + b_2 z^{-2}}{a_0 + a_1 z^{-1} + a_2 z^{-2}}$$ [2, 3].
    *   **Implementação C++:** Utilize a arquitetura *Direct Form II Transposed* [4, 5]. Esta forma requer apenas dois elementos de atraso ($z^{-1}$) por seção e mitiga substancialmente erros de quantização em ponto flutuante [6, 7].
    *   **Passa-Baixa e Passa-Alta:** Os coeficientes ($a_0, a_1, a_2, b_0, b_1, b_2$) devem ser derivados via Transformada Bilinear (BLT) com compensação de *warping* de frequência [8].

*   **Filtros FIR (Fase Linear):**
    Para processamento com preservação rigorosa de fase temporal (crítico para inteligibilidade de fala), utilize filtros FIR [6].
    *   **Janelamento:** Projete filtros FIR (ex: 63-taps) aplicando uma **Janela de Hamming** para truncar a resposta ao impulso infinita e reduzir o vazamento espectral (*spectral leakage*) [9, 10]. A equação do janelamento de Hamming a ser implementada é:
        $$w(n) = 0.54 - 0.46 \cos\left(\frac{2\pi n}{N-1}\right)$$ [11].



### 2. Algoritmo de Expansão de Envelope (TEE)
Para melhorar o reconhecimento de consoantes fricativas (/f/, /s/, /t/) e preservar detalhes finos, o processamento deve atuar nas faixas de alta frequência preservando o contorno temporal.

*   **Lógica Matemática e Compressão *Fast-Acting*:**
    O realce de transientes e consoantes fracas é garantido pela aplicação de compressores de ação rápida (*fast-acting compression*) na banda correspondente à fala [12, 13]. 
    *   Os tempos de ataque (Attack Time - AT) devem ser curtos (aprox. 5 ms) para responder instantaneamente à energia das vogais precedentes, enquanto o tempo de liberação (Release Time - RT) deve ser inferior a 50 ms [14, 15]. 
    *   Isso garante que a audibilidade de consoantes de baixa intensidade ocorrendo imediatamente após vogais de alta intensidade seja restaurada de forma dinâmica [16, 17].



### 3. Gestão de Latência Crítica
O atraso total (*end-to-end latency*) entre a captação do microfone e o transdutor do alto-falante **deve ser mantido abaixo de 20 ms**. Ultrapassar este limite causa o efeito de filtragem em pente (*comb filtering*), distorcendo a percepção de localização espacial do usuário [18].

*   **Integração Flutter e C++:**
    A interface do usuário em Flutter deve comunicar-se com o motor DSP nativo (C/C++) de forma **síncrona** e direta utilizando o protocolo **Dart FFI** (*Foreign Function Interface*). Isto elimina o *overhead* de serialização de mensagens típico dos *Platform Channels* convencionais [19].
*   **Protocolo de Áudio (Mobile):**
    *   **Android:** O motor C++ deve inicializar o áudio usando a biblioteca *Oboe* (chamando nativamente a API AAudio), exigindo o modo `Exclusive` e ativando a flag `Low Latency` para ter acesso direto ao buffer MMAP [20, 21]. O processamento DSP deve usar *callbacks* de dados em uma *thread* separada da interface, sem bloqueios de *mutex* [22, 23].
    *   **iOS:** Deve-se acessar diretamente a API `AudioUnit` (RemoteIO) via C++, configurando `preferredIOBufferDuration` para otimizar os tamanhos de quadros no nível de hardware [19, 24, 25].



### 4. Compensação Dinâmica de Ganho
A adaptação automática baseada no audiograma (*Pure-Tone Average* - PTA) é orquestrada pela Compressão de Faixa Dinâmica Ampla (WDRC). 

*   **Fórmulas e Ajuste:**
    O ganho em cada canal de frequência deve ser computado usando lógicas de *Broken-stick gain function* (ganho linear fixo abaixo do limiar de compressão, ganho com compressão ativa acima deste limiar) [26]. 
    *   **Compression Threshold (CT):** Definido tipicamente entre 40 - 50 dB SPL; o áudio abaixo deste ponto recebe amplificação total (linear) baseada na perda calculada pelo PTA [27].
    *   **Compression Ratio (CR):** Fórmulas de prescrição como NAL-R determinam os coeficientes de ganho; para perdas sensoriais típicas, estabeleça taxas de 1.5:1 a 3:1 [27, 28]. Esta fórmula injeta as pressões de som de entrada para se ajustarem à faixa auditiva que resta ao indivíduo [29].



### 5. Protocolo de Prevenção de Recrutamento
A disfunção nas células ciliadas externas resulta no "recrutamento de loudness", onde o crescimento da sensação de volume aumenta muito rapidamente e de forma desconfortável com a intensidade sonora, limitando drasticamente a faixa dinâmica útil [30-32].

*   **Limitação de Amplitude e Prevenção:**
    Para contornar o recrutamento nas frequências danificadas:
    1.  **Limitadores de Pico (*Peak Limiters*):** Use algoritmos de limitação absoluta e tempos de ataque extremamente rápidos (< 1 ms) colocados como estágio final antes do conversor D/A (DAC). Isto impedirá fisicamente a ultrapassagem do limiar de desconforto [27, 31].
    2.  **Mapeamento não-linear:** O sistema deve combinar o WDRC supracitado com algoritmos de suavização (*soft limiters*) na curva de entrada/saída, garantindo atenuação de sinais que atinjam o teto operacional imposto pelo perfil audiológico específico do usuário, prevenindo dor neurossensorial imediata [27, 29].


Aqui estão os detalhes finais de implementação extraídos das fontes para concluir o nosso manual técnico. Estes blocos detalham a arquitetura final e os parâmetros exatos para o Agente Antigravity implementar no código.
### 6. Implementação de HRTF (Áudio Binaural e Convolução)
Para garantir a percepção de localização espacial 3D e externalização do som, o motor de áudio deve aplicar Funções de Transferência de Cabeça (HRTF) [1-3]. A síntese binaural é alcançada convoluindo o sinal de áudio fonte com a Resposta ao Impulso Relacionada à Cabeça (HRIR) correspondente a cada ouvido, o que injeta as pistas cruciais de Diferença de Tempo Interaural (ITD), Diferença de Nível Interaural (ILD) e espectrais [2-4].

*   **Lógica de Processamento (Convolução Particionada):** Como as funções HRTF exigem filtros FIR longos (ex: 512 ou 1024 *taps*) que introduziriam latência inaceitável em uma convolução linear direta, o sistema deve utilizar a técnica de **Convolução Particionada** (*Partitioned Convolution*) com blocos sobrepostos (como *Overlap-Save* ou *Overlap-Add*) [5, 6].
*   **Vantagem:** Essa técnica divide os filtros longos da HRTF em sub-blocos menores, executando a convolução no domínio da frequência (via Fast Fourier Transform - FFT) [5]. Isso limita o atraso ao tamanho de um único sub-bloco, viabilizando o processamento binaural em tempo real em dispositivos móveis sem comprometer a resolução espacial [5, 7].



### 7. Otimização de Recursos (Diretriz de Crossover FIR vs. IIR)
A fim de maximizar a eficiência da CPU mobile preservando a transparência acústica, a arquitetura de filtragem adotará uma topologia híbrida de bancos de filtros, dividida estritamente na frequência de transição de **1.000 Hz** [8-10].

*   **Abaixo de 1.000 Hz (Filtros IIR - Biquads):** O processamento de baixas frequências exige resoluções de banda muito estreitas, o que forçaria filtros FIR a terem ordens altíssimas e consumirem CPU/latência excessiva [11, 12]. Felizmente, o sistema auditivo humano é muito menos sensível à distorção de fase em baixas frequências [11, 12]. Portanto, nesta faixa, é **obrigatório o uso de filtros IIR (Biquad)**, que entregam as curvas de equalização necessárias consumindo uma fração mínima do processamento [11, 13].
*   **Acima de 1.000 Hz (Filtros FIR / IFIR):** A sensibilidade auditiva a pistas de tempo e fase (fundamentais para a localização espacial e distinção nítida de consoantes) aumenta criticamente nas médias e altas frequências [14, 15]. Nesta região espectral, é **obrigatório o uso de filtros FIR (Fase Linear)** [14, 15]. O uso de FIR garante que transientes de fala não sofram *phase smearing* (borrão de fase) [14, 15]. Para mitigar o custo de CPU, recomenda-se a implementação em topologia IFIR (*Interpolated FIR*) [10, 16, 17].



### 8. Configuração Oboe / FFI para Gestão de Latência Crítica
Para manter a latência *end-to-end* firmemente ancorada abaixo dos 20 ms requeridos, o motor nativo e a ponte Dart devem ser otimizados da seguinte forma:

*   **Configuração AAudio/Oboe:**
    *   **Sharing Mode:** O aplicativo deve solicitar acesso **`EXCLUSIVE`** no Oboe/AAudio [18]. Caso o sistema operacional o conceda, o aplicativo escreverá os dados diretamente no buffer MMAP lido pelo DSP de hardware do dispositivo, bypassando camadas do Android e obtendo a menor latência absoluta [18]. O uso de um modo `SHARED` pode elevar a latência base para mais de 26 ms [19].
    *   **Buffer Size:** A técnica recomendada para o tamanho do buffer utilizável é o *double buffering*. Deve-se sintonizar o tamanho do buffer nativo para ser exatamente o **dobro do tamanho do burst** (sendo o burst equivalente ao tamanho máximo do *callback*) [20].
    *   **Callback de Áudio:** Utilize sempre *data callbacks* em uma thread isolada, certificando-se de não alocar memória dinâmica, não utilizar *mutex/locks* nem executar operações de I/O dentro do *callback*, evitando *buffer underflows* [20-22].

*   **Gestão de Ponteiros com Dart FFI:**
    A gestão manual do C++ via FFI exige a técnica de visualização *zero-copy* unida a um coletor nativo determinístico.
    *   No Dart, a conversão do buffer é feita invocando **`Pointer.asTypedList`**, o que gera um `Float32List` permitindo acesso direto do Dart à memória C++ alocada (por exemplo, via `calloc`) sem copiar os dados [23, 24].
    *   **Prevenção de Memory Leaks:** Para evitar memory leaks advindos de buffers C++ "órfãos", utilize a classe **`NativeFinalizer`** introduzida nas versões modernas do Dart [25, 26]. Ao criar a visualização `asTypedList`, atrele o ponteiro da memória a uma função nativa de liberação (`free` do C++) utilizando o parâmetro `finalizer` [25]. Dessa maneira, o Dart VM garante categoricamente que a função C++ nativa de limpeza será acionada no momento exato em que o objeto correspondente for recolhido pelo *Garbage Collector* [25, 27].



### 9. Matriz de Sharpening (Equalização Paramétrica) para /f/ e /s/
Para realçar transientes rápidos e restabelecer a audibilidade das consoantes sibilantes e fricativas desprovidas de energia grave (com foco especial no som do /s/, que sofre atenuação pesada em pacientes com perda neurossensorial), o engenho empregará um filtro de equalização de pico (*Peaking EQ / Bell Filter*) [28, 29].

Enquanto a labiodental /f/ exibe um espectro plano e difuso, a alveolar /s/ possui um forte pico ressonante na cavidade frontal [30]. O ajuste paramétrico para aumentar a inteligibilidade vocal é o seguinte:

*   **Frequência Central ($f_0$):** O filtro de realce de sibilantes deve ser centrado estritamente na faixa de **5.000 Hz a 6.500 Hz** [31, 32]. Esta zona abrange o pico da média espectral (M1) primária das fricativas alveolares da maior parte dos perfis vocais [31, 32].
*   **Ganho (Gain):** Aplique um *boost* conservador de **+3 dB a +6 dB** [31, 32]. Isto fornece clareza incisiva sem gerar artefatos ríspidos ou degradar a qualidade geral do áudio [31, 32].
*   **Fator de Qualidade ($Q$):** O ajuste do *bandwidth* deve ser cirúrgico para evitar a captura e realce dos formantes de vogais vizinhas. Use um valor $Q$ estrito entre **3.0 e 5.0** [31, 32]. Mais especificamente, recomenda-se o **Fator $Q = 4.32$** (equivalente a uma largura de banda de 1/3 de oitava) [32, 33].

---

## 10. Arquitetura Multicamadas Nativa (Stereo)
O motor nativo foi migrado para uma arquitetura estéreo de baixa latência (Exclusive Mode Oboe) com:
1. **SineOscillator**: Tom puro clínico lateralizado (L/R) calibrado ($1.0 = 80dB HL$).
2. **NoiseGenerator**: Ruído branco para mascaramento e Cocktail Effect.
3. **SamplePlayer Layers**: Áudio PCM para estímulos de fala.