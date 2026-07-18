# Módulo 15 — Documentação, onboarding e DoR/DoD

## Depende de: 14

## Objetivo
Um novo dev (ou agente) sai do clone para o primeiro commit válido seguindo **só o README**. Critérios de pronto-para-começar e pronto-para-entregar ficam escritos e apontados pelo AGENTS.md.

## Entregáveis obrigatórios

### 1. `README.md`
- O que é o projeto (da description dos parâmetros) + **setup em 1 comando** (ou o mínimo real: clone → install → env → db → dev).
- Comandos principais: dev, lint, typecheck, test, verify, generate.
- Ciclo de banco local (migrations + seed, do módulo 08).
- Badge/link do CI.
- Ponteiro para AGENTS.md ("se você é uma IA, comece por lá") e para CONTRIBUTING.

### 2. `CONTRIBUTING.md`
- Fluxo de trabalho: branch → conventional commit → PR → CI verde → merge (branch protection).
- Como rodar as travas localmente e o que cada uma cobra.
- Como adicionar: domínio, migration, action, evento, worker (sempre via `generate`).
- Convenção `scratch/`, política de dependências (aprovação humana + DECISIONS).

### 3. `docs/ARCHITECTURE.md`
- Visão macro: diagrama de domínios e fluxo de eventos entre eles (Mermaid ou ASCII).
- Regra de dependência hexagonal (resumo + link para AGENTS.md).
- Decisões estruturais com link para os ADRs.

### 4. `docs/RUNBOOK.md`
- Operação: como subir em produção, variáveis exigidas, migrations em deploy.
- Incidentes: onde estão os logs estruturados/trace ids, como ler a trilha de audit, health endpoints, procedimento de rollback.
- Mesmo em estágio inicial, criar com as seções e o que já se sabe — placeholders explícitos `TBD` onde faltar experiência real.

### 5. DoR / DoD (no AGENTS.md, seção própria)
**Definition of Ready (antes de começar):**
- `docs/STATUS.md` lido (estado da feature confirmado — não vou reconstruir o que está ✅).
- `CONTEXT.md` do domínio lido.
- Parâmetros claros; decisão arquitetural (se houver) discutida.

**Definition of Done (antes de concluir):**
- `verify-rules` passa · testes passam com cobertura · CI verde.
- `docs/STATUS.md` atualizado (linha da feature: estado + arquivos).
- Entrada em `DECISIONS.md` · skills sincronizadas.
- `/scratch` limpo · nenhum secret exposto · arquivos dentro do limite de linhas · sem dependência nova não-aprovada.

## Regras invioláveis deste módulo
- README testado de verdade, não presumido (ver aceite).
- Nenhuma informação duplicada divergente: README aponta para AGENTS.md, não recopia as leis.

## Critério de aceite
- [ ] **Simulação de onboarding:** em diretório limpo (ou apagando artefatos locais: `node_modules`, `.env`, estado do db), seguir o README literalmente do zero até `npm run verify` + `npm run test` verdes e um commit válido. Qualquer passo que precisou de conhecimento fora do README = corrigir o README e repetir.
- [ ] Os 4 documentos existem com todas as seções listadas.
- [ ] DoR/DoD presentes no AGENTS.md.

## Ao concluir
1. Marcar ✅ na linha 15 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md`.
3. PARAR. Não iniciar o módulo 16 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
