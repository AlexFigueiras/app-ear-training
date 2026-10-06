# BOSYN: MASTER PLAN — SSOT de produto (treino, gamificação, design)
**Versão:** 2.0 (plano "treino eficaz", 2026-10-05)
**Status:** ATIVO

> **Nota de desambiguação:** este arquivo é o SSOT de **produto** (treino, gamificação,
> design). Não confundir com `/MASTER-PLAN.md` na raiz, que rastreia a **fundação de
> governança** (bootstrap Dev OS, ver `AGENTS.md`). O histórico do *porquê* de cada regra está em
> `docs/DECISIONS.md` (entradas "Plano treino eficaz — Etapa 0…12").

## 1. Visão de produto: treino auditivo
O BOSYN é um programa de **treino auditivo** focado na percepção de consoantes agudas (/s/, /f/,
/ʃ/, /t/) e na compreensão da fala no ruído.

**Não é dispositivo médico e não recupera a audição.** Treino não restaura limiar tonal (o dano
é coclear); ele ensina a aproveitar melhor as pistas que ainda chegam ao ouvido.

O que a literatura sustenta:
- o ganho na tarefa treinada é consistente;
- a transferência para a fala do dia a dia é modesta (Henshaw & Ferguson 2013; Ferguson et al.
  2014; Saunders et al. 2016);
- parte da "melhora" é só familiaridade com a tarefa (Amitay et al. 2006).

Por isso o produto segue as condições ligadas à eficácia: pista audível, várias vozes,
dificuldade adaptativa, feedback, dose em minutos/dia e palavras em ruído de fala. E mede o
progresso com material que o treino não usa (§5).

## 2. Diretrizes de UI/UX

### 2.1. Direção visual
- Modo escuro: fundos `#0A0A0A` / `#0D0D0F`.
- Acentos: azul `#2563EB` (ação), verde `#00FF41` / `#4ADE80` (acerto, meta), âmbar
  `#FFBF00` (próximo passo, aviso), vermelho `#F87171` (erro).
- Sem mascotes, sem animações de recompensa infantis.
- **Decisão de produto em aberto:** qual guia visual vale para o app, esta direção ou o design
  system "Ecossistema BOSYN". O código segue esta direção até a decisão.

### 2.2. Regras de acessibilidade (travadas por máquina)
O público principal tem perda auditiva relacionada à idade.
- **Fonte mínima 14, corpo 16+** (`lib/ui/theme/bosyn_text.dart`). O `verify_rules`
  (`check_accessibility`) falha com `fontSize` < 14.
- **Contraste:** texto ≥ AA; nada de `Colors.white10/12/24/30/38` em texto (também travado).
  Contornos de controles ≥ 3:1 (`BosynText.outline`).
- **Toque e leitura:** alvos de toque ≥ 48 dp. Telas roláveis que funcionam em 360×640 com fonte
  em 200% (`test/large_font_test.dart`). Controles com nome para o leitor de tela. App em
  pt-BR (`flutter_localizations`).
- **Linguagem comum** (`docs/GLOSSARIO_UI.md`): sem "Trial", "XP", "SNR", "dB HL", "acuidade".
  Nunca prometer resultado clínico.

## 3. Treinos

| Treino | Tarefa | Dificuldade (escada 3-acertos/1-erro, ~79%) |
|---|---|---|
| **Palavras parecidas** | Qual palavra ouviu, entre 2 | Reforço extra só nas bandas ≥ 3 kHz (24 → 0 dB = nível 1 → 7) |
| **Conversa no barulho** | Qual palavra veio depois de "Diga ___ agora", entre 4 (sala/fala/salas/falas) | SNR com ruído de fala ou burburinho de 6 vozes (+15 → -10 dB = nível 1 → 10) |
| **Voz de um lado, barulho do outro** | Igual ao anterior, com a voz a ±60° e o burburinho do lado oposto (ITD + sombra da cabeça) | SNR, como acima |

Regras comuns:
- **Estímulos** (`lib/training/stimulus_bank.dart`): pares de palavras **reais** por ponto de
  articulação (s×ch, s×f, t×p, t×k) e /s/ final (plural).
  - Qualquer palavra do par pode tocar, então a resposta não é memorizável.
  - Pares de vozeamento (pistas graves) ficam só como aquecimento.
  - 3 vozes do TTS.
- **Seleção** (`item_selector.dart`): mais peso para a faixa de maior perda e para os contrastes
  errados há pouco; sem repetir pares. A guarda de audibilidade tira do sorteio as pistas que a
  melhor orelha não ouve nem no máximo, e orienta a procurar fonoaudiólogo/aparelho.
- **Retorno a cada tentativa:** ✓/✗ com a resposta certa; no erro, "Ouvir as duas" e
  "Continuar".
- **Sessão de ~10 min** com "Terminar", sem punição por erro. A escada é salva entre sessões
  (`profiles.gamification_data.training_state`) e retomada 4 dB mais fácil.
- **Resumo no fim:** acertos, tempo, nível, pontos, recorde e meta do dia.
- **Sinal:** ganho por orelha a partir do audiograma (meio ganho da perda relativa, teto de 25
  dB). Fala normalizada a -30 dBFS RMS; ruído com o mesmo RMS (SNR exato).

## 4. Gamificação (`lib/training/progress_rules.dart`)
- **Pontos de treino por esforço:** 10 por minuto, iguais em todos os treinos, + 50 por recorde
  pessoal (limiar menor que o melhor já alcançado) + 30 ao cumprir a meta do dia.
- **Nível vem do desempenho:** o limiar da escada de cada treino, com os estágios "Começando /
  Avançando / Dominando". Pontos não mudam o nível.
- **Meta:** 15 minutos por dia e 5 dias por semana. "Dias seguidos" conta dias com a meta e é
  recalculado do histórico a cada abertura. A partir de 30 minutos no dia, sugere uma pausa.
- **Progressão por domínio:** Palavras parecidas é recomendada até o nível 5; depois (com o plano
  completo) Conversa no barulho e então Voz de um lado. Recomendação, não bloqueio: o único
  bloqueio é o plano PRO (`GatekeeperService`).
- **Removidos e proibidos de voltar:**
  - Energia Neural (punia o erro que a escada produz de propósito);
  - XP com multiplicador por tipo de fonema;
  - "nível de acuidade" calculado por XP;
  - acerto bruto como medida de progresso.

## 5. Medida de progresso ("Audição na fala")
- **Teste de dígitos no ruído** (`lib/training/digits_in_noise.dart`):
  - 24 trios de dígitos;
  - SRT de 50% (1-acima/1-abaixo, 2 dB);
  - voz própria (não usada no treino);
  - ruído de fala;
  - **sem EQ** (a medida não muda quando o audiograma muda).
- A cada 14 dias, sugerido pela Home. Gráfico em "Meu progresso".
- Sempre rotulado **"medida interna do app, não validada clinicamente"**.

## 6. Teste de audição (triagem relativa)
- **Procedimento:** Hughson-Westlake modificado com tentativas silenciosas (2 de verificação
  antes de aceitar um limiar).
  - "Sem resposta" no máximo.
  - 250 Hz–8 kHz, incluindo 3 e 6 kHz, com reteste de 1 kHz.
  - Tom pulsado com rampas, sem processamento.
  - Fone obrigatório e volume fixo checado.
- **Resultado:** audiograma clínico, categoria OMS aproximada e próximo passo (refazer, procurar
  profissional ou treinar).
- **Sem calibração por equipamento:** os níveis são **relativos**, não dB HL clínico.
- **Precisão em simulação:** ~80% a ±5 dB e ~100% a ±10 dB.

## 7. Motor de áudio
- Motor nativo C++/Oboe (`cpp/`), descrito na skill `DSP_AUDIO_ENGINE`.
- **Cadeia:** EQ de 8 bandas por orelha → direção (ITD + sombra da cabeça) → ruído mixado depois
  do EQ → limitador de segurança a -1 dBFS.
- **Medição:** tons e dígitos usam bypass.
- **Regras de tempo real:** sem alocação, lock ou log no callback, e troca de buffers por
  ponteiro atômico.
- **Testes:** `cpp/tests/` no CI com ASan/UBSan e TSan.

## 8. Pendências de produto
1. **Teste no celular** das Etapas 2–11 (checklist de escuta com fone com fio; TalkBack).
2. **Revisão por fonoaudiólogo** do banco de palavras, dos textos de orientação e dos critérios de
   "procure um profissional".
3. **Etapa 13 (opcional):** rebaixamento de frequência para zonas mortas, só com validação
   profissional.
4. **Decisão do guia visual** (§2.1).
5. **Ações humanas fora do código:**
   - deploy da Edge Function `tts` atualizada;
   - rotação de chaves;
   - migration 003.
