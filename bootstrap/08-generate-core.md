# Módulo 08 — generate core (CLI + migration + action + seed)

## Depende de: 07

## Objetivo
Criar o gerador de blueprints `scripts/generate.js` com os dois templates mais críticos (migration e action) e o seed de banco local. A partir daqui, criar migrations/actions manualmente passa a ser **proibido** (regra 2.2 do protocolo).

## Entregáveis obrigatórios

### 1. `scripts/generate.js` — CLI base
Node.js puro. Roteia subcomandos para módulos em `scripts/lib/`; templates em `scripts/lib/templates/`. `generate.js <tipo>` sem args mostra usage. Comandos deste módulo:
```
node scripts/generate.js migration <tabela>
node scripts/generate.js action <dominio> <nome>
node scripts/generate.js seed
```
(Os comandos `event`, `worker`, `domain`, `sync-skills` chegam no módulo 09 — deixe o roteador preparado.)

### 2. Template de migration
`generate migration <tabela>` cria arquivo timestampado (`YYYYMMDDHHMMSS_create_<tabela>.sql`) no diretório de migrations, contendo:
- `CREATE TABLE` com `id` (uuid/pk), **`tenant_id` NOT NULL + FK** (se multi-tenant), `created_at`, `updated_at`.
- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`.
- Policies de SELECT/INSERT/UPDATE/DELETE restritas ao tenant do usuário (padrão da stack de auth declarada).
- Trigger de `updated_at`.
- `REVOKE` de acesso anônimo quando aplicável.
- Comentário no topo: "gerado por generate.js — edite conforme necessário, mas não remova tenant_id/RLS/policies sem aprovação humana (Lei de Segurança)".

**Todo arquivo gerado já nasce passando no `verify-rules`** — este é o contrato do gerador.

### 3. Template de action/handler
`generate action <dominio> <nome>` cria em `domains/<dominio>/actions/<nome>.ts`:
- Validação de input com schema (Zod/Pydantic) — nunca input cru.
- Checagem de autenticação/autorização no topo (padrão do auth_provider declarado).
- try/catch convertendo erros via `shared/errors/serialize.ts` (módulo 05).
- Log estruturado de entrada/saída via `shared/observability/logger.ts`.
- **Arquivo de teste-esqueleto correspondente** em `__tests__/`.
- Se o domínio não existir ainda, o comando **falha** orientando a rodar `generate domain` (módulo 09) primeiro — não cria estrutura parcial.

### 4. Seed de desenvolvimento (acréscimo ao v3)
- `generate seed` cria/atualiza `infra/db/seed.sql` (ou script da stack) com dados mínimos de desenvolvimento: 1 tenant de teste, 1 usuário por papel.
- Documentar no README futuro o ciclo local: subir banco (ex.: `supabase start`/docker), aplicar migrations, aplicar seed.
- Seed **nunca** roda em produção — guard explícito por env (`NODE_ENV`).

## Regras invioláveis deste módulo
- Templates respeitam TODAS as leis: tamanho, tenant_id, RLS, sem secrets, boundaries.
- `generate.js` e cada template dentro do limite de linhas (modularizar em `scripts/lib/`).
- Nenhuma dependência nova.

## Critério de aceite
- [ ] `node scripts/generate.js` sem args mostra usage com os comandos disponíveis.
- [ ] `generate migration teste_tabela` → arquivo criado → `npm run verify` → exit 0 (o check-migrations do módulo 07 valida o template real). Deletar a migration de teste.
- [ ] **Teste negativo:** remover manualmente a linha de RLS da migration gerada → `npm run verify` → exit 1. Deletar.
- [ ] `generate action` num domínio inexistente → erro orientando `generate domain`.
- [ ] `generate seed` cria o seed com guard de produção.
- [ ] Workspace limpo após os testes.

## Ao concluir
1. Marcar ✅ na linha 08 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` (formato de migration/policies adotado para a stack).
3. PARAR. Não iniciar o módulo 09 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
