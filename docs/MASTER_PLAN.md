# BOSYN: MASTER PLAN - Clinical-Game SSOT
**Versão:** 1.0 (Pivotagem Industrial-Utilitária)
**Status:** ATIVO
**Role Responsável:** [ORQUESTRADOR]

> **Nota de desambiguação (2026-07-18):** este arquivo é o SSOT de **produto** (design,
> gamificação clínica). Não confundir com `/MASTER-PLAN.md` na raiz do repo, que rastreia o
> progresso da **fundação de governança** (bootstrap Dev OS, ver `AGENTS.md`). Ver também
> `#PROJECT_BRAIN.md`, que referencia este arquivo como Norte Estratégico.

## 1. Visão de Produto: treino auditivo
O BOSYN é um programa de **treino auditivo** focado na percepção de consoantes agudas (/s/, /f/, /ʃ/, /t/) e da fala no ruído. **Não é dispositivo médico e não recupera a audição:** treino não restaura limiar tonal (dano coclear); ele ensina a aproveitar melhor as pistas que ainda são audíveis. O ganho na tarefa treinada é consistente; a transferência para a fala do dia a dia é modesta e depende de pista audível, várias vozes, dificuldade adaptativa, feedback e dose (ver `docs/DECISIONS.md`, 2026-10-04).

## 2. Diretrizes de UI/UX: Industrial-Utilitária
O design deve evocar instrumentos de precisão, simuladores de voo e painéis de telemetria médica.

### 2.1. Identidade Visual (Design Tokens)
- **Modo Dark Obrigatório:** Base em cinza carvão (`#0D0D0F`), preto profundo (`#000000`).
- **Acentos de Comando:** Azul Militar (`#2563EB`), Amarelo de Alerta (`#F59E0B`), Vermelho de Interrupção (`#E11D48`).
- **Contraste AAA:** Contraste absoluto para acessibilidade de pacientes.
- **Tipografia:** 
  - **Dados:** Monospaced (ex: Roboto Mono, JetBrains Mono) para telemetria e valores numéricos (Hz, dB, ms).
  - **Interface:** Sans-serif técnica (ex: Inter, Montserrat) com kerning ajustado.
- **Táctilidade:** Botões grandes, com feedback visual de clique "físico", bordas angulares (evitar arredondados excessivos).

### 2.2. Proibições (HARD REJECTION)
- Proibido o uso de mascotes ou avatares cartunescos.
- Proibido animações de "recompensa" lentas ou infantis.
- Proibido paletas de cores "pastel" ou tons "suaves".

## 3. Mecânicas de Retenção Sóbrias (Gamificação Clínica)

### 3.1. Neural Fatigue (Células de Energia)
- O sistema concede **5 Células de Energia** por ciclo.
- Erros em fonemas críticos agudos (`/s/`, `/f/`, `/t/`) consomem 1 célula.
- Ao chegar a 0 energia, o treino é bloqueado por tempo pré-determinado ou até o próximo período de descanso.
- **Justificativa Clínica:** Evitar a fadiga cognitiva que prejudica a plasticidade cortical.

### 3.2. Continuity Protocol (Streaks)
- Foco em "Dias de Estimulação Consecutivos". 
- Multiplicador de XP para sequências ininterruptas (Protocolo de Intensidade).

### 3.3. Acuity Index (XP Técnico)
- O XP reflete a **Acurácia Auditiva**.
- **Multiplicador Agudo:** Peso **2x** para acertos em frequências acima de 4kHz e fonemas sibilantes.

## 4. Roadmap de Estabilidade e Áudio
1. **Zero-Latency & Zero-Overlap:** O motor nativo deve ser interrompido e os buffers limpos via `forceStopAll()` antes de qualquer navegação de tela. 
2. **Segurança de Dados:** RLS no Supabase acionado por `user_id` em 100% das operações de persistência.
3. **Calibragem Centralizada:** Threshold Test como âncora para todos os níveis de treino.
