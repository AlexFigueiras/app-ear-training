# Módulo 05 — Observabilidade obrigatória + padrão de erros

## Depende de: 04

## Objetivo
Todo módulo do sistema nasce com logs estruturados, rastreabilidade, auditoria, métricas, health checks e um contrato único de erros.

## Entregáveis obrigatórios

### 1. `shared/observability/` — cinco arquivos
```
logger.ts    # logs estruturados (JSON) com trace/correlation id
tracing.ts   # OpenTelemetry (vendor-neutral) — spans por request/job
metrics.ts   # contadores/histogramas (estilo Prometheus)
audit.ts     # trilha de auditoria para eventos sensíveis
health.ts    # liveness + readiness
```

Especificações:
- **logger.ts:** saída JSON por linha com `level`, `msg`, `timestamp`, `traceId`, campos extras tipados. API: `logger.info/warn/error(msg, fields?)` + `logger.child({ traceId })`. Zero dependência ou uma lib leve já aprovada como tooling — perguntar antes se for adicionar (pino etc.).
- **tracing.ts:** interface de spans (`startSpan(name) → { end(), setAttribute() }`). Implementação inicial pode ser no-op/console, mas a **interface segue OpenTelemetry** para plugar um exporter real depois sem tocar nos chamadores.
- **metrics.ts:** `counter(name).inc()`, `histogram(name).observe(v)`. Implementação inicial in-memory com endpoint/print de dump.
- **audit.ts:** `audit(event, { actorId, tenantId, target, metadata })` → grava log estruturado imutável (nível `audit`). **Eventos críticos obrigatoriamente auditados:** login, pagamento, mudança de permissão, deleção.
- **health.ts:** `liveness()` (processo vivo) e `readiness()` (dependências OK — usa checks registráveis). Expor endpoint no módulo de entrega quando houver app.

### 2. `shared/errors/` — contrato único de erros (acréscimo ao v3)
O v3 menciona a pasta mas não especifica o contrato. Defina:
- `app-error.ts`: classe base `AppError extends Error` com `code` (string estável de catálogo, ex.: `AUTH_REQUIRED`, `TENANT_MISMATCH`, `NOT_FOUND`, `VALIDATION_FAILED`, `CONFLICT`, `INTERNAL`), `httpStatus` sugerido, `cause?` e flag `expose` (se a mensagem pode ir ao usuário final).
- `codes.ts`: catálogo dos códigos (união de literais, não strings soltas).
- `serialize.ts`: `toResponse(err)` — converte qualquer erro em resposta segura (erros não-`AppError` viram `INTERNAL` sem vazar stack/detalhes) e loga o original via `logger`.
- Regra: entrypoints (`actions/`, handlers, workers) **sempre** convertem erros com `serialize.ts`; nunca `throw` cru até o cliente.

### 3. Testes unitários
- logger: emite JSON válido, propaga `traceId` do child.
- audit: registro contém actor/tenant/evento.
- errors: `AppError` serializa com código; erro desconhecido vira `INTERNAL` sem vazar mensagem interna.

## Regras invioláveis deste módulo
- Nenhuma regra de negócio em `shared/` — só infraestrutura transversal.
- Interfaces vendor-neutral (OTel-like); nenhum SDK de APM específico sem aprovação.
- Cada arquivo dentro do limite de linhas (300 warning / 500 falha).

## Critério de aceite
- [ ] Os 5 arquivos de observability + 3 de errors existem e exportam as interfaces especificadas.
- [ ] Testes passam (`npm run test`).
- [ ] **Teste negativo:** lançar um `Error` genérico por `serialize.ts` → resposta não contém a mensagem/stack original.

## Ao concluir
1. Marcar ✅ na linha 05 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` (contrato de erros e catálogo inicial de códigos).
3. PARAR. Não iniciar o módulo 06 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
