# Módulo 12 — Estratégia de testes com cobertura enforced

## Depende de: 11

## Objetivo
Pirâmide de testes configurada e **verificável por máquina**: cobertura mínima que falha o CI, factories para dados de teste, esqueletos gerados automaticamente.

## Entregáveis obrigatórios

### 1. Runner configurado (Vitest/Jest/pytest conforme stack)
- Config na raiz com descoberta de `*.test.*` e `__tests__/`.
- Scripts `test` e `test:coverage` do módulo 01 funcionando de verdade.

### 2. Pirâmide documentada (no AGENTS.md ou CONTRIBUTING) e aplicada
- **Unit (maioria):** regra pura em `domain/`, testada em memória, rápida, sem I/O. Colocada junto do código (`*.test.ts` ou `__tests__/`).
- **Integração (camada média):** `services` + `adapters` contra DB/fila reais em containers efêmeros (ex.: testcontainers, `supabase start`). Separada por convenção de nome (`*.integration.test.ts`) para poder rodar em job próprio.
- **E2E (poucos):** fluxos críticos ponta-a-ponta; ferramenta conforme stack (Playwright etc. — aprovação humana se for dependência nova).

### 3. Cobertura mínima ENFORCED
- Threshold configurado (ex.: **80% em `domains/`**; o resto pode começar menor e subir).
- `test:coverage` **falha** (exit ≠ 0) abaixo do threshold.
- Passo de cobertura do CI (módulo 11) atualizado: remover o `TODO módulo 12`.

### 4. Factories/fixtures
- `shared/testing/factories/` (ou `__tests__/factories/` por domínio): construtores de entidades de teste com defaults válidos e overrides (`makeTenant()`, `makeUser({ role: 'admin' })`).
- **Nada de dados mágicos espalhados** — valores compartilhados vêm de factory/fixture.

### 5. Geradores atualizados
Confirmar (e corrigir se preciso) que `generate domain` e `generate action` criam esqueleto de teste que **passa** — contrato do módulo 08/09.

## Regras invioláveis deste módulo
- Cobertura é gate, não relatório informativo.
- Testes de `domain/` não tocam I/O — se precisarem, a regra vazou para o lugar errado.

## Critério de aceite
- [ ] `npm run test` verde.
- [ ] **Teste negativo:** baixar temporariamente o threshold impossível (ex.: 99.9%) ou plantar módulo sem teste em `domains/` → `npm run test:coverage` exit ≠ 0. Reverter.
- [ ] Factory usada em pelo menos um teste real.
- [ ] CI atualizado com o threshold ativo.

## Ao concluir
1. Marcar ✅ na linha 12 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` (thresholds e ferramentas escolhidas).
3. PARAR. Não iniciar o módulo 13 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
