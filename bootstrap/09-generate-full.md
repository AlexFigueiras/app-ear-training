# Módulo 09 — generate full (event, worker, domain, sync-skills)

## Depende de: 08

## Objetivo
Completar o gerador com os quatro comandos restantes e criar o primeiro domínio real do projeto pela via oficial — provando o pipeline inteiro.

## Entregáveis obrigatórios

### 1. `generate event <nome>`
- Cria `events/<event-name>.ts`: schema do payload (Zod/Pydantic) + tipo exportado + **versão** (`v1` no nome do tipo ou campo `version`).
- Registra automaticamente em `events/registry.ts` (catálogo central: nome → schema → versão). Criar o `registry.ts` agora, com o bus **in-process síncrono** mínimo (`publish`/`subscribe` tipados pelo registry). O contrato versionado é o que permite migrar para SQS/Kafka/NATS depois sem reescrever domínios.
- Convenção de nomes: passado, kebab-case (`customer-created`, `invoice-paid`).
- Eventos críticos (auth, pagamento, permissão, deleção) chamam `audit()` do módulo 05 ao serem publicados.

### 2. `generate worker <nome>`
- Cria `worker/<nome>.ts` (ou Route Handler, conforme deploy_target) com: **idempotência** (chave de deduplicação), **retry com backoff**, **rate-limit** configurável, logging estruturado com traceId, conversão de erros via `shared/errors`.
- Teste-esqueleto correspondente.

### 3. `generate domain <nome>`
Cria a estrutura completa de `domains/<nome>/` (anatomia do módulo 03): `CONTEXT.md`, `index.ts` (vazio de exports, com comentário "API pública — só exporte o que for contrato"), `types.ts`, `schema.ts`, `domain/`, `services/`, `ports/`, `adapters/`, `actions/`, `events/`, `__tests__/` com um teste placeholder que passa.

Template do `CONTEXT.md`:
```md
# <Domínio> — CONTEXT
## Propósito         # 1 frase
## Modelo            # entidades e invariantes principais
## API pública       # o que index.ts expõe (e o que NÃO expõe)
## Eventos           # publica / consome
## Regras locais     # DDL/RLS (se db), masks/forms (se ui), idempotência (se worker)
## Gotchas           # armadilhas conhecidas
```

Ao gerar um domínio, adicionar automaticamente a linha dele no **Mapa de Contexto** do `AGENTS.md` (domínio → responsabilidade → caminho do CONTEXT.md) — ou instruir e conferir manualmente.

### 4. `generate sync-skills`
- Copia cada `domains/*/CONTEXT.md` → `.claude/skills/<dominio>/SKILL.md` e `.gemini/skills/<dominio>/SKILL.md` (com frontmatter/cabeçalho exigido pela ferramenta, se houver).
- Idempotente: rodar duas vezes não gera diff.
- (O pre-commit do módulo 10 vai rodá-lo automaticamente.)

### 5. Criar o(s) primeiro(s) domínio(s) reais
Rodar `generate domain <nome>` para cada item de `initial_domains` dos parâmetros. **Não implementar regra de negócio ainda** — só a estrutura. Registrar cada um como ⬜ no `docs/STATUS.md`.

## Regras invioláveis deste módulo
- Nenhum domínio criado manualmente — só pelo gerador.
- `index.ts` é a única superfície pública; nada exportado por conveniência.

## Critério de aceite
- [ ] `generate event teste-criado` → contrato + entrada no registry → `npm run verify` exit 0. Deletar evento de teste e entrada.
- [ ] `generate domain <primeiro-dominio-real>` cria estrutura completa; teste placeholder passa; linha no Mapa de Contexto do AGENTS.md; linha ⬜ no STATUS.md.
- [ ] `generate sync-skills` → SKILL.md espelham os CONTEXT.md; segunda execução sem diff.
- [ ] **Teste negativo de boundaries com estrutura real:** import de internals entre dois domínios gerados → `npm run verify` exit 1. Reverter.
- [ ] `generate worker teste` → arquivo com idempotência/retry/rate-limit presentes. Deletar.

## Ao concluir
1. Marcar ✅ na linha 09 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` (domínios iniciais criados, transporte de eventos fase 1).
3. PARAR. Não iniciar o módulo 10 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
