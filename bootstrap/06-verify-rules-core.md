# Módulo 06 — verify-rules core (runner + tamanho + secrets)

## Depende de: 05

## Objetivo
Criar o *enforcer* central: `scripts/verify-rules.js`, runner modular que retorna exit 0/1, com os dois primeiros checks (tamanho de arquivo e secrets em código cliente). As travas nascem ANTES dos geradores para que todo código futuro já nasça validado.

## Entregáveis obrigatórios

### 1. `scripts/verify-rules.js` — o runner
Node.js puro (zero dependências), modular. Saída legível: cores, agrupada por categoria, warnings vs failures. Exit 0 se passa, exit 1 se qualquer check falha.

Esqueleto obrigatório:
```js
// scripts/verify-rules.js
const checks = [
  require('./lib/check-file-size'),
  require('./lib/check-client-secrets'),
  // módulos 07 adicionam: check-migrations, check-domain-boundaries,
  // check-circular-deps, check-status-doc
];

(async () => {
  const results = [];
  for (const check of checks) results.push(await check.run());
  const failures = results.filter(r => r.status === 'fail');
  const warnings = results.filter(r => r.status === 'warn');

  warnings.forEach(w => console.warn(`⚠️  ${w.name}: ${w.message}`));
  failures.forEach(f => console.error(`❌ ${f.name}: ${f.message}`));

  if (failures.length) {
    console.error(`\n${failures.length} verificação(ões) falharam.`);
    process.exit(1);
  }
  console.log('✅ Todas as verificações passaram.');
  process.exit(0);
})();
```
Contrato de cada check: `scripts/lib/check-*.js` exporta `{ name, async run() -> { name, status: 'pass'|'warn'|'fail', message } }`. Mantê-los pequenos — os próprios scripts respeitam o limite de linhas; se crescerem, quebram em `scripts/lib/`. **O Dev OS pratica o que prega.**

### 2. `scripts/lib/check-file-size.js`
- Varre arquivos de código (`.ts/.tsx/.js/.jsx/.py/...`, conforme stack), ignorando `node_modules`, builds, `scratch/`.
- Conta **linhas líquidas** (ignora comentários e linhas em branco).
- `> 300` líquidas → **warn** · `> 500` → **fail**.
- **Baseline/catraca para brownfield:** arquivos listados em `scripts/lib/file-size-baseline.json` (caminho → linhas registradas) viram warn em vez de fail, mas **falham se CRESCEREM** além do valor registrado. Arquivos novos seguem 300/500 normalmente. Crie o arquivo (vazio `{}` em greenfield). O baseline só diminui — reduzir o número registrado conforme os arquivos são modularizados.

### 3. `scripts/lib/check-client-secrets.js`
- Identifica arquivos cliente (heurística por stack: `'use client'` no Next.js; diretórios de bundle frontend em outras).
- **Fail** ao encontrar neles: `SERVICE_ROLE_KEY`, `createAdminClient`, nomes de envs server-only do schema do módulo 04, padrões de chave privada (`-----BEGIN`, `sk_live_`, `AKIA...`).
- **Fail** também para secrets hardcoded fora de `.env*` em QUALQUER arquivo (valores literais com formato de token/senha).

### 4. Wire no `package.json`
`"verify": "node scripts/verify-rules.js"` (já criado no módulo 01; confirmar que funciona).

## Regras invioláveis deste módulo
- Zero dependências novas no runner (Node puro).
- Um check por arquivo em `scripts/lib/`; nenhum "check Deus".

## Critério de aceite (testes negativos obrigatórios — um verify vazio também "passa")
- [ ] `npm run verify` → exit 0 no estado atual.
- [ ] **Plantar** arquivo com 600 linhas líquidas de código → `npm run verify` → exit 1. Deletar.
- [ ] **Plantar** arquivo com 350 linhas → warning (exit 0). Deletar.
- [ ] **Plantar** `'use client'` contendo `SERVICE_ROLE_KEY` → exit 1. Deletar.
- [ ] Registrar um arquivo fake no baseline com N linhas, plantá-lo com N+10 → exit 1. Limpar baseline e arquivo.
- [ ] Workspace limpo após os testes (Poluição Zero — `git status`).

## Ao concluir
1. Marcar ✅ na linha 06 do `MASTER-PLAN.md` com os resultados dos testes negativos.
2. Entrada no `DECISIONS.md`.
3. PARAR. Não iniciar o módulo 07 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status — inclusive CADA teste negativo executado e seu exit code. Se algo ficou de fora, o módulo NÃO está concluído.
