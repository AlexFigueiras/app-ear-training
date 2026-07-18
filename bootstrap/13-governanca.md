# Módulo 13 — Governança de dependências e commits

## Depende de: 12

## Objetivo
Commits previsíveis, changelog automático, dependências auditadas e atualizadas por processo — não por improviso.

## Entregáveis obrigatórios

### 1. Conventional Commits validados por hook
- Hook `commit-msg` (via lefthook/`.githooks`, mesmo mecanismo do módulo 10) validando o formato `tipo(escopo?): descrição` com tipos `feat|fix|chore|refactor|docs|test|perf|ci|build`.
- Validador zero-dependência (regex em script Node) ou commitlint (tooling da fundação — listar + DECISIONS).

### 2. Changelog automático
- Escolher e configurar UMA ferramenta: Changesets, semantic-release ou git-cliff (conforme stack/fluxo de release). Se exigir dependência, é tooling da fundação (listar + DECISIONS).
- `CHANGELOG.md` inicial criado; processo documentado no CONTRIBUTING (módulo 15).

### 3. Atualização automatizada de dependências
- `renovate.json` OU `.github/dependabot.yml` versionado, com PRs agrupados/semanais e lockfile atualizado.

### 4. Auditoria de vulnerabilidades no CI
- Passo no `ci.yml`: `npm audit --audit-level=high` / `pip-audit` / `cargo audit` conforme stack. Gate, não aviso (nível mínimo que falha: high).

### 5. Reafirmar as regras no AGENTS.md (se ainda não explícitas)
- Lockfile **sempre** versionado; CI instala congelado (já feito no módulo 11 — conferir).
- Dependência nova de runtime exige aprovação humana prévia **e** registro em `DECISIONS.md`.

## Regras invioláveis deste módulo
- Nenhuma ferramenta de release publica nada automaticamente sem aprovação humana configurada (PR de release, não publish direto).

## Critério de aceite
- [ ] **Teste negativo:** `git commit -m "mensagem qualquer sem tipo"` → rejeitado pelo commit-msg hook.
- [ ] `git commit -m "chore: teste de convencao"` (vazio, com `--allow-empty`) → aceito. Remover o commit de teste (`git reset`).
- [ ] Config do Renovate/Dependabot presente e válida.
- [ ] Passo de audit presente no CI e sem `continue-on-error`.

## Ao concluir
1. Marcar ✅ na linha 13 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` (ferramenta de changelog e política de updates).
3. PARAR. Não iniciar o módulo 14 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
