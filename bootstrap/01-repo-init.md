# Módulo 01 — Inicialização do repositório

## Depende de: 00

## Objetivo
Repositório git funcional com configuração base da stack, higiene de arquivos e scripts de package prontos para receber os módulos seguintes.

## Entregáveis obrigatórios

Adapte nomes/arquivos à stack declarada no MASTER-PLAN (exemplos abaixo assumem Node/TypeScript; para Python use `pyproject.toml` + `uv`, etc.):

### 1. Repositório git
- `git init` (se ainda não for repo) com branch padrão `main`.

### 2. `.gitignore`
Deve conter no mínimo: `node_modules/`, `.env` e variantes (`.env.local`, `.env*.local`), artefatos de build (`.next/`, `dist/`, `coverage/`), **`/scratch/`** (rascunhos efêmeros — regra de Poluição Zero), logs e caches.

### 3. `.env.example`
Versionado, com as chaves esperadas e **sem valores reais**. Comece com as variáveis mínimas da stack (ex.: URL do banco, chave anônima). O `.env` real é gitignored.

### 4. `.editorconfig`
`indent_style`, `indent_size`, `end_of_line = lf`, `insert_final_newline = true`, `trim_trailing_whitespace = true`.

### 5. `package.json` (ou equivalente)
Scripts obrigatórios — os alvos podem ser stubs que ainda falham, mas os nomes já existem para os módulos seguintes preencherem:
```json
{
  "scripts": {
    "dev": "<start dev server>",
    "lint": "<linter>",
    "typecheck": "<tsc --noEmit ou equivalente>",
    "test": "<runner de testes>",
    "test:coverage": "<runner com cobertura>",
    "verify": "node scripts/verify-rules.js",
    "generate": "node scripts/generate.js"
  }
}
```

### 6. `tsconfig.json` (stacks tipadas)
**`strict: true` obrigatório.** Sem `any` implícito. Erros de tipo devem falhar o build.

### 7. Convenção `scratch/`
`scratch/` é o único lugar para rascunhos persistentes de agentes e está **gitignored** (não crie `.gitkeep` dentro dela — ela nunca entra no repo). Garanta a entrada no `.gitignore`; o README (módulo 15) documentará a convenção.

### 8. Tooling de fundação (exceção auto-autorizada)
A única exceção à regra "nenhuma dependência sem consentimento" são as ferramentas de tooling da fundação: linter, formatter, hook manager (lefthook), dependency-cruiser/madge, framework de teste. Você PODE instalá-las como devDependencies **agora ou nos módulos que as usam** — mas deve listá-las explicitamente ao humano nesta resposta e registrá-las depois no `DECISIONS.md` (módulo 02). Dependências de **runtime** continuam proibidas sem consentimento.

## Regras invioláveis deste módulo
- Nenhuma dependência de runtime.
- Nenhum código de produto (nada em `app/`, `domains/` etc. — isso é módulo 03).
- `.env` jamais versionado.

## Critério de aceite
- [ ] `git status` limpo após commit inicial.
- [ ] `.env` está no `.gitignore` (teste negativo: crie `.env` com conteúdo fake, confirme que `git status` não o lista, delete-o).
- [ ] `scratch/` está no `.gitignore`.
- [ ] Typecheck roda (mesmo sem arquivos: `npm run typecheck` → exit 0).
- [ ] Todos os 7 scripts existem no `package.json`.

## Ao concluir
1. Marcar ✅ na linha 01 do `MASTER-PLAN.md` com o comando de verificação usado.
2. PARAR. Não iniciar o módulo 02 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
