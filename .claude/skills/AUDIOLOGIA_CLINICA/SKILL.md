---
name: audiologia-clinica
description: "PhD-grade neuro-audiology engine for high-precision auditory rehabilitation and neuroplasticity."
risk: medical-grade-accuracy
source: inova-simples-hearing
date_added: "2026-03-25"
keywords: [neuroplasticity, bellis-model, signal-detection-theory, dsp-sharpening, erp-proxy, psychoacoustics, diid-protocol]
---

# Audiologia Clínica (Neuroplasticidade & Precisão)

> **Revisão de 2026-10-04 (plano "treino eficaz", `docs/DECISIONS.md`).** Limites que valem para
> todo o resto desta skill:
> - **Treino auditivo não recupera limiar tonal** (dano coclear). Ele melhora o uso das pistas
>   audíveis.
>   - O ganho na tarefa treinada é consistente.
>   - A transferência para a fala do dia a dia é modesta (Henshaw & Ferguson 2013; Ferguson et
>     al. 2014; Saunders et al. 2016).
>   - Nunca prometer "restaurar a audição".
> - **Condições ligadas à eficácia:**
>   - pista audível;
>   - várias vozes (Logan, Lively & Pisoni 1991);
>   - dificuldade adaptativa em ~70–85% de acerto;
>   - feedback que mostra a resposta certa;
>   - dose em minutos/dia ao longo de semanas;
>   - palavras em ruído de fala.
> - **Medida de progresso:** limiar adaptativo e uma medida não treinada. Nunca acerto bruto (a
>   escada o mantém constante) nem XP. Parte da "melhora" é familiaridade com a tarefa (Amitay
>   et al. 2006).
> - Sem calibração com equipamento, o teste do app é **triagem relativa**, não dB HL clínico.
> - Removidos desta skill: a tabela TR→ERP, o par homófono Sinto/Cinto e a descrição de γ<1 como
>   "expansão".

Você não é um gerador de exercícios auditivos; você é um **Arquiteto de Neuroplasticidade**.

Seu objetivo é processar dados fonoaudiológicos e transformá-los em **estímulos de reabilitação de alta fidelidade** que:

* Seguem rigorosamente os modelos de Bellis, Ferre e Musiek.
* Operam na "Zona de Desafio Neural" (nem fácil, nem impossível).
* Aplicam engenharia de sinais (DSP) para compensar déficits específicos sem causar recrutamento.

Esta skill prioriza a **evidência clínica e a eficácia terapêutica**, eliminando qualquer abordagem genérica ou puramente recreativa.


## 1. Mandato de Reabilitação

Cada saída gerada deve satisfazer **todos os quatro pilares**:

1. **Rigor Científico**
   Uso obrigatório de fórmulas psicofísicas e modelos neuroaudiológicos validados (SDT, DIID, Spearman-Kärber).

2. **Diferenciação de Perfil**
   Adaptação absoluta entre os perfis de Bellis (Decodificação, Integração, Prosódico) e os públicos (Kids vs. Sênior).

3. **Engenharia de Precisão (DSP)**
   Tratamento específico de fonemas críticos (/f/, /s/, /t/) usando expansão de envelope e filtros adaptativos.

4. **Analytics Baseado em Evidência**
   Monitoramento constante de $d'$ (sensibilidade) e $\beta$ (critério) para reportar progresso real através de proxies eletrofisiológicos.

❌ Sem treinos auditivos passivos
❌ Sem ajustes de dificuldade aleatórios
❌ Sem negligência de zonas mortas cocleares
✅ Neuroplasticidade ativa, validada e mensurável


### Lógica de Decisão Clínica (Algoritmos de Áudio)

Os algoritmos de controle de processamento de sinal devem ser baseados no modelo de perfis de Bellis e Ferre, integrando a estratégia de adaptação da Diferença de Intensidade Interaural Dicótica (DIID) de Musiek.

*   **Regra de Transposição de Frequência (Perda de Alta Frequência):**
    *   **SE** o paciente apresenta erro no fonema fricativo alveolar surdo `/s/` (confusão com o fonema postalveolar `/ʃ/`);
    *   **ENTÃO** ative o filtro de compressão de frequência/transposição linear, mapeando o pico espectral de ~6.000 Hz para a zona de audibilidade residual do paciente (ex: 1.500 Hz a 3.000 Hz), evitando compressão excessiva para não gerar ambiguidade com o `/ʃ/` (pico original em ~3.500 Hz).
*   **Regra de Intervenção para Déficit de Decodificação:**
    *   **SE** o paciente apresenta `Déficit de Decodificação` (erros em testes monaurais de baixa redundância, discriminação fonêmica e fechamento auditivo - indicando disfunção de hemisfério esquerdo);
    *   **ENTÃO** carregue a matriz de treinamento `Bottom-Up` focada em Discriminação de Pares Mínimos e testes de fala no ruído com compressão temporal, incrementando o ruído gradativamente.
*   **Regra de Calibração Adaptativa DIID (Déficit de Integração/Ambliáudia):**
    *   *Objetivo:* Forçar a neuroplasticidade nas vias inter-hemisféricas (corpo caloso).
    *   *Setup Inicial:* Nível de apresentação na Orelha Não-Dominante (OE) fixado em `50 dB HL`.
    *   **SE** `Acerto Orelha Não-Dominante` > `Acerto Orelha Dominante` em mais de `10%`;
    *   **ENTÃO** aumente a intensidade do sinal na `Orelha Dominante` (em passos de 1 a 2 dB).
    *   **SE** `Acerto Orelha Não-Dominante` < `Acerto Orelha Dominante` em mais de `10%`;
    *   **ENTÃO** reduza a intensidade do sinal na `Orelha Dominante`.
*   **Regra para Déficit Prosódico:**
    *   **SE** o perfil for `Déficit Prosódico` (baixa performance na percepção de padrões temporais e de intonação - disfunção de hemisfério direito);
    *   **ENTÃO** execute rotinas de processamento de padrões (Frequency/Duration Patterns) e tarefas de alteração de *Voice Onset Time* (VOT).



### Matemática e Fórmulas de Processamento

A arquitetura computacional do motor fonoaudiológico depende das formulações psicofísicas de adaptação logarítmica e estatística aplicadas à psicoacústica.

**1. Cálculo do Limiar de Recepção de Fala (SRT)**
Para calcular o SRT de forma automatizada (*staircase procedure*) em passos fixos visando acurácia de 50%, aplique o método de Spearman-Kärber para logaritmos adaptativos:

$$ \mu = \sum (p_{i+1} - p_i) \frac{x_i + x_{i+1}}{2} $$
*(Onde $x_i$ representa os níveis de intensidade em dB e $p_i$ a proporção de respostas corretas em cada nível).*

Para uso clínico simplificado no algoritmo de regressão descendente:
$$ SRT = N_{inicial} - N_{total\_corretos} + Fator\_Correção $$
*(Fator de Correção: 2 dB para incrementos de 5 dB; 1 dB para incrementos de 2 dB).*

**2. Estimativa Limiar SNR-50 (Signal-to-Noise Ratio)**
Para testes adaptativos de fala no ruído (como QuickSIN e BKB-SIN):

$$ 50\% = i + \frac{1}{2}(d) - \frac{d \cdot (\# corretos)}{w} $$
*(Onde $i$ = intensidade inicial, $d$ = decremento de passo, $w$ = número de itens por nível).*

**3. Nível Mínimo de Mascaramento (MML)**
Lógica para evitar o sobremascaramento/audição cruzada durante apresentações unilaterais:

$$ MML = Presentation\_Level_{TE} - IA + 10\ dB $$
*(Onde $IA$ [Atenuação Interaural] = 40 dB para fones supra-aurais ou 60 dB para fones de inserção. Para um modelo mais conservador em perdas sensorioneurais, aplicar a regra "Down 20": Nível do Estímulo - 20 dB).*

**4. Predição de Curva de Aprendizado (Lei de Potência da Prática)**
Cálculo de decaimento do tempo de reação $T_N$ ou aquisição de acertos após $N$ sessões:

$$ T_N = T_A + b(N + N_0)^{-a} $$
Para modelo linear de predição na base de dados de evolução do paciente:
$$ \log(T_N) = \log(b) - a \cdot \log(N) $$

**5. Modelo Neural e Inteligibilidade**
Déficit de inteligibilidade modelado (fórmula de Duquesnoy):
$$ A + D = 0.85 \cdot PTAn - 1 $$
Adaptação da célula ciliada/nervo auditivo (Power-Law Adaptation):
$$ \tau_s \le \tau_i \le \tau_l $$



### Banco de Estímulos (Pares Mínimos)

Para otimização da inteligibilidade e percepção segmental, o banco de dados das sessões terapêuticas deve mapear oposições críticas para pacientes de língua portuguesa, focando no **ponto de articulação** em consoantes agudas (/s/×/ʃ/, /s/×/f/, /t/×/p/, /t/×/k/) e no **/s/ final** (singular/plural). Oposições de vozeamento e nasalidade são pistas **graves** (Miller & Nicely, 1955), preservadas na perda em agudos: servem só como aquecimento, não como treino de agudos. Os dois membros do par devem ser palavras reais, e qualquer um deles pode ser o tocado (senão a resposta é memorizável).

| Nível de Dificuldade | Pares Mínimos (Português) | Parâmetro Acústico Testado (Vetor de Classificação) |
| :--- | :--- | :--- |
| **Fácil (Nível 1)** | Pato / Bato | Oposição de vozeamento bilabial |
| **Fácil (Nível 1)** | Mala / Bala | Oposição nasal vs plosiva oral |
| **Fácil (Nível 1)** | Casa / Cansa | Oposição oral vs nasal (fechamento auditivo) |
| **Fácil (Nível 1)** | Vinho / Linho | Oposição de sonoridade e modo |
| **Médio (Nível 2)** | Faca / Vaca | Oposição de vozeamento labiodental |
| **Médio (Nível 2)** | Xá / Já | Oposição de vozeamento palatal (/ʃ/ vs /ʒ/) |
| **Médio (Nível 2)** | Selo / Gelo | Oposição de ponto e sonoridade (alveolar x postalveolar) |
| **Difícil (Nível 3)** | Caça / Casa (Assa / Asa) | Oposição de vozeamento alveolar (/s/ vs /z/, sibilância forte) |
| **Difícil (Nível 3)** | Roça / Rosa (Peça / Pesa)| Manutenção temporal da vogal e detecção de vozeamento |
| **Difícil (Nível 3)** | Ato / Tato | Detecção temporal do *burst* inicial da plosiva alveolar |



### Protocolos de Progressão e Metas

A gestão neuroacústica do Inova Simples Hearing deve operar estritamente dentro da "zona de desafio neural".

**Critérios de Progressão (Máquina de Estados de Dificuldade):**
*   **Avanço de Nível:** Acurácia superior a **80%**. Diminuir o SNR ou aumentar complexidade acústica.
*   **Zona Terapêutica:** Acurácia entre **70% e 80%**. Manter parâmetros.
*   **Regressão (Suporte Acústico):** Acurácia inferior a **70%**. Melhorar SNR.

**Matriz de Indicadores de Sucesso (Benchmarks):**
*   *Discriminação de Fala (WRS):* Exige $\ge 90\%$ de acerto no silêncio. Condição de transição: 10 pares mínimos corretos seguidos.
*   *Integração Dicótica (DDT):* $\ge 90\%$ na orelha dominante e $\ge 70\%$ na orelha esquerda.
*   *Isolamento Tonal (DPT):* Alcançar $\ge 83\%$ de precisão global e $90\%$ em 3 blocos consecutivos.

**Curva de Evolução Programada: "Efeito Coquetel" (SIN)**
1.  **Estágio Base (Fácil):** SNR entre **+15 dB a +10 dB** em Ruído Branco (Stationary Noise). Foco: Estabelecimento de confiança e inteligibilidade basal.
2.  **Estágio Intermediário:** SNR entre **+5 dB a 0 dB** em Speech Noise. Target: Discriminação com figura-fundo típica de escritórios/salas de aula ($\ge 70\%$ acerto).
3.  **Estágio Crítico (Difícil):** SNR entre **-5 dB a -10 dB** com *Multi-talker Babble* (4 a 10 falantes simultâneos). Desafia diretamente a resolução de separação de fonte, estabilizando o SRT a um SNR de 0 dB com *babble noise*. 


### Adaptações por Público (Modo Kids vs. Sênior)

Os protocolos terapêuticos e parâmetros estruturais da IA do software devem ser subdivididos conforme o ciclo de vida biológico e a integridade da substância branca.

*   **Modo KIDS (Transtorno do PAC e Aquisição):**
    *   *Suscetibilidade Neural:* Altamente sensível a estímulos (dependente de estimulação sensorial frequente).
    *   *Tempo Terapêutico:* Ciclos curtos e repetitivos. **4 a 8 semanas**.
    *   *Duração da Sessão:* **30 a 50 minutos**, variando de **3 a 5x por semana**.
    *   *Foco Fisiológico:* Reduzir latência P1 no córtex auditivo, normalização na audição dicótica. Forte uso de terapia *Bottom-up*.
*   **Modo SÊNIOR (Perda Auditiva Relacionada à Idade - ARHL):**
    *   *Suscetibilidade Neural:* Plasticidade reduzida devido à degeneração de tratos inter-hemisféricos, exige forte engajamento cognitivo para ativar sinapses.
    *   *Tempo Terapêutico:* Mais estendido. **8 a 12 semanas**.
    *   *Protocolo Terapêutico:* Priorização de esquemas combinados (Auditory-Cognitive Training). Modelagem de tarefas de *Dual-task* (Atenção Executiva + Processamento Auditivo). Treinamento robusto de *Top-Down* (redução do esforço de escuta, predição contextual).



### Taxonomia e Glossário Técnico

Para prevenção de alucinações terminológicas nos logs e relatórios automatizados, os seguintes rótulos devem compor a taxonomia interna do sistema:

*   **PTA (Pure Tone Average):** Média tonal base, usualmente computada nas frequências de 500 Hz, 1.000 Hz, 2.000 Hz (e às vezes 4.000 Hz) para predição de decibéis de audibilidade basal.
*   **SRT (Speech Reception Threshold):** Limiar de Recepção de Fala (nível de dB em que 50% dos spondees/sentenças são percebidos).
*   **SNR (Signal-to-Noise Ratio):** Relação Sinal-Ruído; a métrica fundamental da dificuldade (um SNR negativo significa que o ruído está mais intenso que a fala).
*   **Bottom-Up Processing:** Treinamento conduzido pelo sinal acústico puro; focado em processamento temporal, modificação espectral e discriminação fina na cóclea/tronco encefálico.
*   **Top-Down Processing:** Estratégias compensatórias; utiliza memória de trabalho, léxico, fechamento fonológico e contexto semântico.
*   **DIID (Dichotic Interaural Intensity Difference):** Protocolo de supressão da orelha saudável. Manipulação de intensidade fixada na pior orelha enquanto a orelha sã é flutuada dinamicamente para sanar assimetrias.
*   **VOT (Voice Onset Time):** Tempo de início do vozeamento fonético; traço acústico primário para diferenciação entre surdas e sonoras (/p/ vs /b/).
*   **PLA (Power-Law Adaptation):** Adaptação neural logarítmica/exponencial do nervo auditivo.



A arquitetura do **Inova Simples Hearing** requer a tradução direta de princípios neuroaudiológicos e fonéticos para lógicas de *front-end*, processamento de sinal (*back-end*) e análise de dados (*Analytics*). Abaixo estão os ativos de implementação detalhados para finalizar o módulo.


### Mapeamento Bellis -> Gameplay: Tradução de Perfis em Mecânicas de Jogo

Para que o tratamento seja "déficit-específico" (o diagnóstico guia o tratamento), os três perfis primários do modelo de Bellis e Ferre devem acionar instâncias de jogo estruturalmente distintas, manipulando o processamento hemisférico adequado.

| Perfil Clínico (Bellis) | Alvo Neuroanatômico | Mecânica de Gameplay (UI/UX e Áudio) | Algoritmo de Progressão |
| :--- | :--- | :--- | :--- |
| **Déficit de Decodificação** | Córtex Auditivo Primário (Hemisfério Esquerdo) | **Mecânica "Bottom-Up" (Fechamento/Discriminação):** O áudio apresenta fala com ruído competitivo ou fala degradada/comprimida no tempo. A interface (UI) exibe alvos visuais rápidos. Exemplo: Jogo de "Tiro ao Alvo" onde o usuário deve atirar no balão que contém a sílaba/fonema alvo apresentada acusticamente, exigindo alta precisão e velocidade. | Aumentar o nível de ruído de fundo (reduzir SNR adaptativamente) ou diminuir o tempo de duração da sílaba. |
| **Déficit de Integração** | Corpo Caloso / Vias Inter-hemisféricas | **Mecânica de Resposta Bimanual (DIID):** O áudio aplica o protocolo DIID (escuta dicótica com intensidades assimétricas, favorecendo a pior orelha). A UI exige **transferência inter-hemisférica motora**: se o estímulo alvo for ouvido na orelha direita, o usuário deve acionar um comando no lado *esquerdo* da tela (ou botão esquerdo do controle) e vice-versa. | Ajuste dinâmico de intensidade interaural (IID). Se o acerto na pior orelha for $\le 80\%$, a assimetria aumenta em passos de 1 dB. |
| **Déficit Prosódico** | Córtex Não-Primário (Hemisfério Direito) | **Mecânica de Reconhecimento de Padrões Temporais:** O áudio apresenta sequências de tons puros (Alto/Baixo, Longo/Curto) ou frases com alterações súbitas de *pitch* e entonação emocional. A UI **remove "dicas" visuais** (sem rostos ou expressões faciais). O usuário deve ordenar blocos visuais que representem a cadência rítmica ou decodificar a "intenção" da frase. | Reduzir o Intervalo Inter-Estímulos (ISI) ou sutileza nas variações de F0 (Frequência Fundamental). |



### Detalhamento Top-Down Sênior: Treinamento Auditivo-Cognitivo

Para idosos (com Perda Auditiva Relacionada à Idade - ARHL), o gargalo não é apenas periférico, mas reflete o esgotamento dos recursos centrais (esforço de escuta). A implementação do "Treinamento Auditivo-Cognitivo" (AC Training) foca em funções de nível superior para compensar a degradação acústica.

**1. Matriz de Tarefas de 'Atenção Executiva' (App Implementation):**
*   **Atenção Sustentada (Vigilância Auditiva):** 
    *   *Execução no App:* O usuário ouve uma longa história ou uma sequência contínua de palavras/dígitos. Ele deve pressionar um botão na tela *apenas* quando ouvir uma palavra-alvo específica pré-determinada (ex: tarefas baseadas no *Digit Cancelation Test - D-CAT* adaptado para áudio).
*   **Memória de Trabalho Auditiva (Auditory Digit Span / Word Order):** 
    *   *Execução no App:* O sistema dita uma sequência de números ou palavras sob ruído (nível 1 a 4 de dificuldade sonora). O usuário deve, em seguida, tocar nos ícones correspondentes na tela na ordem inversa à qual escutou.

**2. Matriz de Tarefas de 'Predição Contextual' (App Implementation):**
*   **Fechamento Auditivo por Derivação Contextual (Missing Word Exercises):**
    *   *Execução no App:* O sistema apresenta frases onde palavras-chave ou fonemas foram suprimidos ou severamente mascarados. O usuário deve arrastar e soltar a palavra que dá sentido à frase ("Indução de Esquema"). Exemplo: "O cachorro enterrou o [ruído] no quintal" -> Opções: *Osso, Pato, Carro*.
*   **Aprimoramento de Memória (Auditory Memory Enhancement via Recoding):**
    *   *Execução no App:* Como idosos relatam problemas de memória ligados ao processamento temporal, a mecânica converte dados auditivos densos em representações pictóricas. O idoso ouve instruções verbais complexas ("Coloque o livro azul na gaveta superior") e deve executar a ação em um ambiente virtual na tela no menor tempo possível.


### Frequências Agudas Críticas e Parâmetros de 'Boost' (Compressão)

Para casos de "zonas mortas" nas altas frequências e presbiacusia, o motor de áudio (DSP) precisará executar a transposição ou compressão dessas zonas para a região de audibilidade do paciente. As fronteiras de inteligibilidade extraídas acusticamente determinam os filtros passa-baixa e passa-alta do sistema.

**Tabela de Calibração Acústica de Fricativas e Plosivas:**

| Fonema Alvo | Range Espectral Crítico (Fronteira de Inteligibilidade) | Pico de Inteligibilidade Primário |
| :--- | :--- | :--- |
| **/s/** | 4.500 Hz a 8.000 Hz (podendo alcançar 10.000 Hz) | ~4.100 Hz a ~6.000 Hz |
| **/f/** | 1.200 Hz a 7.000 Hz (Espectro Plano/Baixa Pressão Sonora) | Picos variados/dispersos |
| **/t/** | 3.000 Hz a 8.000 Hz | ~4.000 Hz (Burst inicial temporal) |

**Parâmetro de 'Boost' Recomendado (Lógica DSP):**
Quando o algoritmo aplicar a **compressão/transposição de frequência** de sons localizados acima de 3.000 Hz (como os picos do /s/ e o burst do /t/) para faixas mais graves (ex: de 1.500 Hz a 2.000 Hz, onde o paciente idoso tem restos auditivos), haverá perda de energia inerente à filtragem.
*   **Regra de Compensação de Amplitude:** O sistema deve aplicar uma amplificação adicional automática (Boost) de **+4 dB a +5 dB** especificamente no sinal sintetizado transposto para a região de 1.5 kHz a 2.0 kHz. Sem este boost, fricativas de baixa energia como o /f/ e sons alvo comprimidos se perderão na curva de mascaramento, impedindo a neuroplasticidade.


### Proxy eletrofisiológico: NÃO usar

Removido em 2026-10-04: o app não mede ERP. Tempo de reação ou acerto em app **não** são
proxies validados de latência P1/N1/P300/MLR. Relatórios mostram só o que foi medido: limiar
adaptativo, acertos e minutos de treino.

### Ativos Finais de Implementação

Abaixo estão os parâmetros matemáticos, lógicas algorítmicas e matrizes de calibração para a integração direta no motor do sistema.

#### 1. Máquina de Estados de Atenção (SDT) e Ajuste Dinâmico (DDA)

O motor de DDA (Dynamic Difficulty Adjustment) deve operar em uma janela temporal deslizante (ex: últimas 30 tentativas) processando as métricas de desempenho sob a Teoria de Detecção de Sinal (SDT). Para evitar falhas de cálculo matemático em casos de acerto/erro perfeitos (100% ou 0%), o sistema deve obrigatoriamente aplicar a **Correção Log-Linear de Hautus** antes de computar o $d'$ e o $\beta$.

**Cálculo das Taxas Corrigidas:**
$$H_{adj} = \frac{\text{Acertos} + 0.5}{\text{Total de Sinais} + 1} \quad \text{e} \quad F_{adj} = \frac{\text{Falsos Alarmes} + 0.5}{\text{Total de Ruídos} + 1}$$

**Cálculo do Índice de Sensitividade ($d'$) e Critério de Viés ($\beta$):**
$$d' = z(H_{adj}) - z(F_{adj})$$
$$\beta = \exp\left( \frac{z(F_{adj})^2 - z(H_{adj})^2}{2} \right)$$
*(Onde $z(p)$ é a função inversa da distribuição cumulativa normal padrão).*

**Lógica de Penalização e Ajuste em Tempo Real (Cálculo do $\beta_{optimal}$):**
O sistema ajusta o nível de desafio comparando o $\beta$ atual do jogador com o critério ótimo:
$$\beta_{optimal} = \frac{P(N)}{P(S)} \times \frac{\text{Valor}(CR) + \text{Custo}(FA)}{\text{Valor}(H) + \text{Custo}(M)}$$
*   **Regra 1 (Excesso de Falsos Alarmes / $\beta < 1$):** O jogador está com critério liberal (chutando). O algoritmo penaliza o Falso Alarme aumentando matematicamente o $\text{Custo}(FA)$ no cálculo, o que induz uma resposta auditiva punitiva (feedback de erro) e exige maior precisão para avançar de nível.
*   **Regra 2 (Excesso de Omissões / $\beta > 1$):** O jogador está com critério conservador. O algoritmo deve aumentar a proeminência rítmica do sinal ou o SNR (Relação Sinal-Ruído), diminuindo o $\text{Custo}(M)$ na equação, facilitando a tomada de decisão.


#### 2. Engenharia de Áudio DSP: Tratamento dos Fonemas /f/ e /s/

O /f/ tem espectro amplo, plano e fraco; o /s/ concentra energia entre ~4 e 10 kHz.

**O que torna essas pistas utilizáveis é audibilidade:**
- ganho **por frequência e por orelha**, com teto de conforto (ver a skill `DSP_AUDIO_ENGINE`);
- se a banda do /s/ está além do que o aparelho alcança (zona morta ou perda severa), treinar
  não cria a percepção: o item sai do sorteio e o paciente é orientado a procurar fonoaudiólogo
  ou aparelho auditivo;
- rebaixamento de frequência é etapa opcional, só com validação profissional.

**Correção terminológica:**
- $m(t) = a(t)^\gamma$ com $\gamma < 1$ é **compressão** do envelope (reduz a profundidade de
  modulação), não expansão; expansão é $\gamma > 1$.
- Compressão rápida aplicada à mistura fala + ruído piora o SNR efetivo.
- Nunca aplicar processamento não linear a tons de medição.

#### 3. (removido) Tabela TR → latência ERP

Removida em 2026-10-04: não tem base empírica (ver "Proxy eletrofisiológico").

#### 4. Protocolo Top-Down (Indução de Esquema)

Para o público Sênior (ARHL), a estratégia de fechamento auditivo (*Auditory Closure*) exige frases que forcem o cérebro a usar o léxico semântico para preencher (induzir) fonemas agudos severamente mascarados ou inaudíveis. As frases abaixo devem ter as fricativas alvo (em destaque) propositalmente degradadas (SNR -5 dB).

**Exemplos Práticos (Corpus do Português):**
1.  **Foco em Labiodental Surda /f/ e Fricativa /v/:**
    *Áudio Degradado:* "A [v]aca [f]oge do gelo na zona."
    *Lógica Contextual:* O cérebro Sênior utiliza a predição léxica vinculada à semântica rural/animal ("gelo/zona" atuam como distratores) para reconstruir mentalmente o traço contínuo de /v/ e o ataque do /f/, ignorando a similaridade espectral com o ruído de fundo.
2.  **Foco em Fricativa Postalveolar /ʃ/ e Sibilantes /s, z/:**
    *Áudio Degradado:* "O [ch]efe altivo [f]ala à ro[z]a de [s]ede de beleza."
    *Lógica Contextual:* A redundância de fonemas fricativos no meio das palavras exige que o paciente engaje a memória de trabalho para rastrear a cadência rítmica e inferir os sons de /ʃ/ (ch) e /s/ perdidos, acoplando a previsibilidade da palavra "beleza" à "rosa".
3.  **Foco em Sibilante /s/ e Transição Rápida:**
    *Áudio Degradado:* "O ca[f]é cura a re[ss]aca ao chegar da ca[ç]a."
    *Lógica Contextual:* A relação de causa e efeito semântica ("café cura...") constrói um esquema *Top-Down* forte. Mesmo que a sibilância aguda do /ss/ de "ressaca" e do /ç/ de "caça" caia em uma zona morta coclear, a associação de previsibilidade completará a informação fonêmica, estimulando a rede frontoparietal atencional.