# Módulo 10 — Git hooks versionados e compartilháveis

## Depende de: 09

## Objetivo
Pre-commit que roda o verify-rules e sincroniza skills — **versionado no repo**, chegando a todo dev e agente após o clone.

> ⚠️ **Correção crítica de design.** Hooks em `.git/hooks/` **não são versionados** e não chegam aos outros colaboradores — o que contradiz o objetivo de colaboração consistente. **Nunca** instale o hook lá diretamente. Use uma das estratégias abaixo.

## Entregáveis obrigatórios

### 1. Estratégia versionada (escolher UMA e registrar no DECISIONS)

**Opção A — Lefthook (recomendado, agnóstico de linguagem):** `lefthook.yml` na raiz:
```yaml
# lefthook.yml
pre-commit:
  parallel: false
  commands:
    verify:
      run: node scripts/verify-rules.js
    sync-skills:
      run: node scripts/generate.js sync-skills && git add .claude/skills .gemini/skills
```
Lefthook é tooling da fundação (devDependency auto-autorizada — listar ao humano + DECISIONS).

**Opção B — `core.hooksPath` (zero dependência):**
```bash
git config core.hooksPath .githooks   # diretório VERSIONADO
# .githooks/pre-commit (executável, chmod +x)
```

### 2. Fluxo do pre-commit (qualquer opção)
1. `node scripts/verify-rules.js` → **aborta o commit em vermelho** se falhar (RLS, tamanho, secret, boundary).
2. `node scripts/generate.js sync-skills`.
3. `git add .claude/skills .gemini/skills` silenciosamente (skills entram no mesmo commit).
4. Concluir.

### 3. Bootstrap automático pós-clone
Passo `prepare`/`postinstall` no `package.json` (ou alvo no Makefile) que instala/ativa o hook manager automaticamente após `install` — senão o time esquece de ativá-lo:
```json
{ "scripts": { "prepare": "lefthook install" } }
```
(Opção B: `prepare` roda o `git config core.hooksPath .githooks`.)

### 4. Permissões
Hooks com bit de execução configurado e commitado (relevante na Opção B).

## Regras invioláveis deste módulo
- Nada instalado manualmente em `.git/hooks/`.
- O hook roda os MESMOS comandos que o CI rodará (módulo 11) — nunca uma versão "mais leve".

## Critério de aceite
- [ ] Clone simulado: `rm -rf` da instalação do hook + `npm install` → hook reinstalado automaticamente pelo `prepare`.
- [ ] **Teste negativo:** plantar violação (arquivo 600 linhas), `git add`, tentar `git commit` → commit **abortado** com saída em vermelho. Limpar.
- [ ] Commit legítimo alterando um `CONTEXT.md` → SKILL.md correspondente entra sincronizado **no mesmo commit**.

## Ao concluir
1. Marcar ✅ na linha 10 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` (opção A ou B e por quê).
3. PARAR. Não iniciar o módulo 11 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
