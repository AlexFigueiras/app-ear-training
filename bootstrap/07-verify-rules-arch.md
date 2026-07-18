# Módulo 07 — verify-rules arquitetura (migrations, boundaries, ciclos, status)

## Depende de: 06

## Objetivo
Completar o enforcer com os checks de banco, boundaries de domínio, dependências circulares e o lembrete de STATUS. Ao final deste módulo, todas as leis do AGENTS.md têm enforcement automático.

## Entregáveis obrigatórios

### 1. `scripts/lib/check-migrations.js`
Para cada migration em `infra/db/migrations/` (ou caminho da stack, ex. `supabase/migrations/`) que crie tabela:
- **Fail** se a tabela não tem coluna de isolamento (`tenant_id`/`org_id`) **e** não está na allowlist de tabelas globais (`scripts/lib/tenant-allowlist.json` — criar com as globais óbvias: `tenants`/`orgs`, configs globais).
- **Fail** se não habilita RLS (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`) — ou, em banco sem RLS nativo, se não existe teste de isolamento correspondente na camada de adapters.
- **Fail** se não define **pelo menos uma** `CREATE POLICY`.
- Aplica-se apenas se `multi_tenant: true` nos parâmetros; senão, o check reporta `pass` explicando por quê.

### 2. `scripts/lib/check-domain-boundaries.js`
- **Fail** para import cross-domain de internals: `domains/A/**` importando `domains/B/<qualquer coisa que não seja o index público>`.
- **Fail** para `app/`, `worker/`, `infra/` importando internals de domínio (só `domains/<x>/index.ts` é permitido de fora).
- **Recomendação sênior:** prefira ferramenta testada em batalha a regex frágil — `dependency-cruiser` (regras declarativas) no ecossistema JS/TS, `import-linter` em Python. O check orquestra a ferramenta; forneça também um **fallback zero-dependência via AST/parse de imports** para ambientes restritos. Se instalar a ferramenta (tooling da fundação): listar ao humano + DECISIONS.

### 3. `scripts/lib/check-circular-deps.js`
- **Fail** ao detectar ciclo (`A → B → C → A`), em qualquer nível. Via `dependency-cruiser`/`madge --circular` ou o fallback AST.

### 4. `scripts/lib/check-status-doc.js` (warning — nunca bloqueia)
- Se há mudança de código **em stage** (`domains/`, `app/`, `worker/`, migrations) mas `docs/STATUS.md` não foi tocado → **warn** lembrando de atualizar o estado da feature. Usa `git diff --cached --name-only`; em CI ou sem stage, `pass`.
- Racional (registrar no comentário do check): contexto é "pull" — disponibilizar um arquivo não força a leitura; o lembrete automatizado fecha o ciclo.

### 5. Registrar os 4 checks no runner
Adicionar às `checks` do `verify-rules.js` na ordem: migrations, boundaries, circular, status-doc.

## Regras invioláveis deste módulo
- Boundaries e ciclos são **fail**, nunca warn. Status-doc é **warn**, nunca fail.
- Fallback sem dependências deve existir mesmo que a ferramenta esteja instalada.

## Critério de aceite (testes negativos obrigatórios)
- [ ] `npm run verify` → exit 0 no estado atual.
- [ ] **Plantar** migration criando tabela sem `tenant_id`/RLS/policy → exit 1 (se multi-tenant). Deletar.
- [ ] **Plantar** dois pseudo-domínios `domains/a/` e `domains/b/` com `a/services/x.ts` importando `domains/b/services/y.ts` → exit 1. Trocar o import para `domains/b/index.ts` → boundaries passa. Deletar ambos.
- [ ] **Plantar** ciclo `a → b → a` → exit 1. Deletar.
- [ ] Stage de um arquivo em `domains/` sem tocar `docs/STATUS.md` → warning aparece, exit 0. Unstage.
- [ ] Workspace limpo após os testes (`git status`).

## Ao concluir
1. Marcar ✅ na linha 07 do `MASTER-PLAN.md` com os resultados dos testes negativos.
2. Entrada no `DECISIONS.md` (ferramenta de boundaries escolhida + fallback).
3. PARAR. Não iniciar o módulo 08 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status — inclusive CADA teste negativo executado e seu exit code. Se algo ficou de fora, o módulo NÃO está concluído.
