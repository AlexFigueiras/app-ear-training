# Módulo 16 — Auto-verificação final

## Depende de: 15 (todos os anteriores ✅ no MASTER-PLAN)

## Objetivo
Provar, com execução real e evidência exibida, que a fundação inteira está de pé. Nada de "deve estar funcionando" — rodar e mostrar.

## Entregáveis obrigatórios

Execute **nesta ordem** e mostre o resultado de cada item:

1. **Árvore completa do projeto** (`tree -I node_modules` ou equivalente).
2. **Lista de todos os arquivos criados** pelo bootstrap, com 1 linha de propósito cada.
3. **Resumo arquitetural:** domínios existentes, boundaries, fluxo de eventos.
4. **Stack Adapter preenchido:** tabela final de como cada lei universal se materializa na stack (conferir contra a seção 9 do AGENTS.md).
5. **Comandos** documentados e funcionais: desenvolvimento · validação (`verify`, lint, typecheck, test) · geração (`generate ...`).
6. Rodar `node scripts/verify-rules.js` e **exibir a saída** (deve passar).
7. Rodar `node scripts/generate.js sync-skills` e confirmar sincronização (sem diff pendente).
8. Confirmar hook instalado de forma **versionada** (mostrar `lefthook.yml`/`core.hooksPath`; provar que NÃO depende de `.git/hooks/` manual) e CI configurado.
9. Confirmar que `docs/STATUS.md` existe, é apontado como 1ª leitura no AGENTS.md e **reflete o estado real** — em brownfield, auditado a partir do código e backfillado.

### Checklist de completude (confirmar item a item, com evidência)

- [ ] Context Engine (AGENTS.md + ponteiros + DECISIONS.md/ADR) criado
- [ ] `docs/STATUS.md` criado, apontado como 1ª leitura, refletindo o estado real
- [ ] Topologia por domínio (DDD + hexagonal) com `domains/`, `events/`, `shared/`, `infra/`
- [ ] Boundaries e event-driven com enforcement automático (testes negativos do 07 registrados)
- [ ] Leis de segurança (multi-tenant, RLS, sem creds no cliente, env validation, secret scan)
- [ ] Observabilidade (logger, tracing OTel, metrics, audit, health) + contrato de erros
- [ ] `verify-rules.js` + `generate.js` modulares, dentro do limite de linhas
- [ ] Hooks versionados (lefthook/core.hooksPath) — NÃO em `.git/hooks/`
- [ ] CI rodando os mesmos checks + branch protection (ou pendência humana explícita)
- [ ] Estratégia de testes com cobertura enforced no CI
- [ ] Governança de deps + conventional commits + changelog
- [ ] Skills nativas sincronizadas
- [ ] Docs de onboarding + DoR/DoD
- [ ] MASTER-PLAN.md com os 17 módulos ✅ e coluna "Verificado por" preenchida

### Encerramento
- Última entrada no `DECISIONS.md`: "Bootstrap Dev OS concluído" com data e resumo.
- `docs/STATUS.md`: linha "Fundação Dev OS" = ✅; features de produto seguem ⬜, prontas para serem implementadas **uma a uma, daqui em diante, sob as regras instaladas**.
- Limpar qualquer resíduo em `scratch/` e conferir `git status` limpo após o commit final.

## Critério de aceite
- [ ] Itens 1–9 executados com saída exibida (não descrita).
- [ ] Checklist de completude 100% com evidência por item.
- [ ] Se QUALQUER item falhar: voltar ao módulo correspondente, corrigir, e re-executar este módulo do início.

## Ao concluir
1. Marcar ✅ na linha 16 do `MASTER-PLAN.md`.
2. O bootstrap está encerrado. Desenvolvimento de features segue o protocolo do AGENTS.md (DoR → implementação via generate → DoD).

## Cláusula anti-simplificação
Nenhum item é opcional. "Confirmado" sem saída de comando exibida não conta como confirmação.
